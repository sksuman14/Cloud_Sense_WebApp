import json
import os
import ssl
import hashlib
import random
import pg8000.native

def parse_db_url(url_str):
    clean = url_str.replace('postgresql://', '').replace('postgres://', '')
    user_pass, host_db = clean.split('@')
    user, password = user_pass.split(':')
    host_port, database = host_db.split('/')
    if '?' in database:
        database = database.split('?')[0]
    if ':' in host_port:
        host, port = host_port.split(':')
        port = int(port)
    else:
        host = host_port
        port = 5432
    return user, password, host, port, database

DB_URL = os.environ.get('DATABASE_URL') or 'postgresql://postgres:ksdma_secure_password_2026@ksdmakerala.cmxq78syaxbf.us-east-1.rds.amazonaws.com:5432/ksdmadb'

def hash_pass(pwd_str):
    if not pwd_str:
        return ''
    return hashlib.sha256(pwd_str.encode('utf-8')).hexdigest()

def lambda_handler(event, context=None):
    headers = {
        'Content-Type': 'application/json'
    }

    try:
        http_method = event.get('httpMethod')
        if not http_method and 'requestContext' in event:
            http_method = event['requestContext'].get('http', {}).get('method')
        http_method = (http_method or 'GET').upper()

        path = event.get('path') or event.get('rawPath') or ''

        # Instant CORS OPTIONS preflight handler
        if http_method == 'OPTIONS':
            return {
                'statusCode': 200,
                'headers': headers,
                'body': json.dumps({'status': 'ok'})
            }

        body = {}
        if event.get('body'):
            try:
                raw_body = event['body']
                body = json.loads(raw_body) if isinstance(raw_body, str) else raw_body
            except Exception:
                body = {}

        # Route 0: POST /api/send-otp - Approach 1: AWS Cognito User Pool OTP Dispatcher (6-Digit OTP)
        if '/send-otp' in path and http_method == 'POST':
            identifier = str(body.get('identifier', body.get('email', body.get('mobile_number', '')))).strip()
            email_addr = str(body.get('email', '')).strip()
            if not email_addr and '@' in identifier:
                email_addr = identifier

            otp_code = str(random.randint(100000, 999999))

            # Approach 1: AWS Cognito User Pool OTP Dispatch (App Client ID: 49bvgnea50gvvs00fts6s1pmml)
            if email_addr:
                try:
                    import boto3
                    cognito = boto3.client('cognito-idp', region_name='us-east-1')
                    client_id = "49bvgnea50gvvs00fts6s1pmml"

                    try:
                        cognito.forgot_password(
                            ClientId=client_id,
                            Username=email_addr
                        )
                        print(f"AWS Cognito OTP Email sent to {email_addr}")
                    except cognito.exceptions.UserNotFoundException:
                        try:
                            # Register user in Cognito User Pool to send official verification OTP
                            cognito.sign_up(
                                ClientId=client_id,
                                Username=email_addr,
                                Password=f"Ksdma#{otp_code}!",
                                UserAttributes=[{'Name': 'email', 'Value': email_addr}]
                            )
                            print(f"AWS Cognito SignUp Verification OTP sent to {email_addr}")
                        except Exception as signup_err:
                            print("Cognito SignUp Exception:", signup_err)
                    except Exception as cog_err:
                        print("AWS Cognito Exception:", cog_err)
                except Exception as top_cog_err:
                    print("AWS Cognito Top Exception:", top_cog_err)

            # Send Native AWS SNS SMS if mobile number provided
            try:
                import boto3
                clean_num = identifier.replace(' ', '').replace('-', '')
                if clean_num.isdigit():
                    if len(clean_num) == 10:
                        clean_num = f"+91{clean_num}"
                    elif not clean_num.startswith('+'):
                        clean_num = f"+{clean_num}"

                    sns = boto3.client('sns', region_name='us-east-1')
                    sns.publish(
                        PhoneNumber=clean_num,
                        Message=f"Your KSDMA Weather Network Verification OTP is {otp_code}. Valid for 5 minutes.",
                        MessageAttributes={
                            'AWS.SNS.SMS.SMSType': {
                                'DataType': 'String',
                                'StringValue': 'Transactional'
                            }
                        }
                    )
            except Exception as sns_err:
                print('AWS SNS SMS Exception:', sns_err)

            return {
                'statusCode': 200,
                'headers': headers,
                'body': json.dumps({
                    'success': True,
                    'otp': otp_code,
                    'message': f'Verification OTP sent to {identifier}'
                })
            }

        user, password, host, port, database = parse_db_url(DB_URL)
        ssl_ctx = ssl.create_default_context()
        ssl_ctx.check_hostname = False
        ssl_ctx.verify_mode = ssl.CERT_NONE

        con = pg8000.native.Connection(
            user=user,
            password=password,
            host=host,
            port=port,
            database=database,
            ssl_context=ssl_ctx
        )

        # Self-healing DB Schema Migrations
        try:
            con.run("ALTER TABLE stations ADD COLUMN IF NOT EXISTS rejection_reason TEXT;")
            con.run("ALTER TABLE stations DROP COLUMN IF EXISTS moderation_reason;")
            con.run("ALTER TABLE observations ADD COLUMN IF NOT EXISTS moderation_reason TEXT;")
        except Exception as migration_err:
            print("Migration Notice:", migration_err)

        try:
            # Route 1: POST /api/register
            if '/register' in path and http_method == 'POST':
                mobile = str(body.get('mobile_number', '')).strip()
                name = str(body.get('full_name', '')).strip()
                email = str(body.get('email', '')).strip()
                role = str(body.get('user_role', 'VOLUNTEER')).strip().upper()
                category = str(body.get('role_category', 'generalPublic')).strip()
                raw_pwd = str(body.get('password', body.get('password_hash', ''))).strip()
                pwd_h = hash_pass(raw_pwd)
                user_id = f"usr_{mobile}" if mobile else f"usr_{os.urandom(4).hex()}"

                con.run("""
                    INSERT INTO kusers (user_id, full_name, email, mobile_number, password_hash, user_role, role_category, status)
                    VALUES (:user_id, :full_name, :email, :mobile_number, :password_hash, :user_role, :role_category, 'active')
                    ON CONFLICT (user_id) DO UPDATE SET
                      full_name = EXCLUDED.full_name,
                      email = EXCLUDED.email,
                      mobile_number = EXCLUDED.mobile_number,
                      password_hash = COALESCE(NULLIF(EXCLUDED.password_hash, ''), kusers.password_hash),
                      role_category = EXCLUDED.role_category;
                """, user_id=user_id, full_name=name, email=email, mobile_number=mobile, password_hash=pwd_h, user_role=role, role_category=category)

                con.run("""
                    INSERT INTO volunteer_streaks (user_id, current_streak, max_streak, total_contributions, badge)
                    VALUES (:user_id, 0, 0, 0, 'BRONZE')
                    ON CONFLICT (user_id) DO NOTHING;
                """, user_id=user_id)

                u_obj = {
                    'user_id': user_id,
                    'full_name': name,
                    'email': email,
                    'mobile_number': mobile,
                    'user_role': role,
                    'role_category': category,
                    'status': 'active'
                }
                return {'statusCode': 200, 'headers': headers, 'body': json.dumps({'success': True, 'user': u_obj}, default=str)}

            # Route 2: POST /api/login - Fetch User Profile & Volunteer Streaks / Badges from AWS RDS PostgreSQL DB
            elif '/login' in path and http_method == 'POST':
                mobile = str(body.get('mobile_number', '')).strip()
                email = str(body.get('email', '')).strip()

                rows = []
                sql_q = """
                    SELECT u.user_id, u.full_name, u.email, u.mobile_number, u.user_role, u.role_category, u.status,
                           u.password_hash,
                           COALESCE(s.current_streak, 0) AS current_streak,
                           COALESCE(s.total_contributions, 0) AS total_contributions,
                           COALESCE(s.max_streak, 0) AS max_streak,
                           COALESCE(s.badge, 'BRONZE') AS badge
                    FROM kusers u
                    LEFT JOIN volunteer_streaks s ON u.user_id = s.user_id
                """
                if mobile:
                    rows = con.run(sql_q + " WHERE u.mobile_number = :mobile LIMIT 1;", mobile=mobile)
                elif email:
                    rows = con.run(sql_q + " WHERE LOWER(u.email) = LOWER(:email) LIMIT 1;", email=email)

                if rows:
                    cols = ['user_id', 'full_name', 'email', 'mobile_number', 'user_role', 'role_category', 'status', 'password_hash', 'current_streak', 'total_contributions', 'max_streak', 'badge']
                    u_obj = dict(zip(cols, rows[0]))
                    u_obj.pop('password_hash', None)
                    return {'statusCode': 200, 'headers': headers, 'body': json.dumps({'success': True, 'user': u_obj}, default=str)}
                else:
                    return {'statusCode': 404, 'headers': headers, 'body': json.dumps({'success': False, 'message': 'User profile not found'}, default=str)}

            # Route 3: POST /api/observations - Submit / Edit Daily Observation
            elif '/observations' in path and http_method == 'POST':
                obs_id = str(body.get('observation_id') or f"OBS-{os.urandom(4).hex()}")
                stn_id = str(body.get('station_id', ''))
                user_id = str(body.get('submitted_by_user_id', 'usr_anon'))
                obs_date = str(body.get('observation_date', '')).split('T')[0]
                obs_time = str(body.get('observation_time', '08:00:00'))

                rainfall = float(body['rainfall_mm']) if body.get('rainfall_mm') is not None else None
                max_temp = float(body['max_temperature_c']) if body.get('max_temperature_c') is not None else None
                min_temp = float(body['min_temperature_c']) if body.get('min_temperature_c') is not None else None
                river_lvl = float(body['river_water_level_m']) if body.get('river_water_level_m') is not None else None
                humidity = float(body['humidity_percent']) if body.get('humidity_percent') is not None else None
                source = str(body.get('source', 'MANUAL_ENTRY'))

                con.run("""
                    INSERT INTO observations (
                        observation_id, station_id, submitted_by_user_id, observation_date, observation_time,
                        rainfall_mm, max_temperature_c, min_temperature_c, river_water_level_m, humidity_percent, source, status
                    )
                    VALUES (
                        :obs_id, :stn_id, :user_id, :obs_date::date, :obs_time::time,
                        :rainfall, :max_temp, :min_temp, :river_lvl, :humidity, :source, 'approved'
                    )
                    ON CONFLICT (station_id, observation_date) DO UPDATE SET
                        submitted_by_user_id = EXCLUDED.submitted_by_user_id,
                        observation_time = EXCLUDED.observation_time,
                        rainfall_mm = COALESCE(EXCLUDED.rainfall_mm, observations.rainfall_mm),
                        max_temperature_c = COALESCE(EXCLUDED.max_temperature_c, observations.max_temperature_c),
                        min_temperature_c = COALESCE(EXCLUDED.min_temperature_c, observations.min_temperature_c),
                        river_water_level_m = COALESCE(EXCLUDED.river_water_level_m, observations.river_water_level_m),
                        humidity_percent = COALESCE(EXCLUDED.humidity_percent, observations.humidity_percent),
                        submission_timestamp = CURRENT_TIMESTAMP;
                """, obs_id=obs_id, stn_id=stn_id, user_id=user_id, obs_date=obs_date, obs_time=obs_time,
                     rainfall=rainfall, max_temp=max_temp, min_temp=min_temp, river_lvl=river_lvl, humidity=humidity, source=source)

                # Update volunteer streak count for unique dates
                rows_cnt = con.run("SELECT COUNT(DISTINCT observation_date) FROM observations WHERE submitted_by_user_id = :user_id;", user_id=user_id)
                cnt = rows_cnt[0][0] if (rows_cnt and rows_cnt[0][0]) else 1

                con.run("""
                    INSERT INTO volunteer_streaks (user_id, current_streak, max_streak, total_contributions, last_observation_date)
                    VALUES (:user_id, :cnt, :cnt, :cnt, :obs_date::date)
                    ON CONFLICT (user_id) DO UPDATE SET
                        total_contributions = EXCLUDED.total_contributions,
                        current_streak = EXCLUDED.current_streak,
                        max_streak = GREATEST(volunteer_streaks.max_streak, EXCLUDED.max_streak),
                        last_observation_date = EXCLUDED.last_observation_date;
                """, user_id=user_id, cnt=cnt, obs_date=obs_date)

                return {'statusCode': 200, 'headers': headers, 'body': json.dumps({'success': True, 'message': 'Observation saved successfully'})}

            # Route 4: GET /api/observations - Fetch Observations
            elif '/observations' in path and http_method == 'GET':
                rows = con.run("""
                    SELECT observation_id, station_id, submitted_by_user_id, observation_date, observation_time,
                           submission_timestamp, rainfall_mm, max_temperature_c, min_temperature_c,
                           river_water_level_m, humidity_percent, source, status, flag_reason
                    FROM observations
                    ORDER BY observation_date DESC, observation_time DESC;
                """)
                cols = ['observation_id', 'station_id', 'submitted_by_user_id', 'observation_date', 'observation_time',
                        'submission_timestamp', 'rainfall_mm', 'max_temperature_c', 'min_temperature_c',
                        'river_water_level_m', 'humidity_percent', 'source', 'status', 'flag_reason']
                observations = [dict(zip(cols, r)) for r in rows]
                return {'statusCode': 200, 'headers': headers, 'body': json.dumps({'success': True, 'observations': observations}, default=str)}

            # Route 5: POST /api/approve - Admin Approve Station in AWS RDS Database
            elif '/approve' in path:
                stn_id = body.get('station_id', '')
                if not stn_id:
                    parts = [p for p in path.split('/') if p and p != 'api' and p != 'stations' and p != 'approve']
                    stn_id = parts[0] if parts else ''

                admin_id = str(body.get('approved_by', body.get('admin_id', 'usr_admin_hq'))).strip()

                con.run("""
                    UPDATE stations
                    SET approval_status = 'approved',
                        approved_by = :admin_id
                    WHERE station_id = :stn_id OR station_id LIKE :stn_like;
                """, admin_id=admin_id, stn_id=stn_id, stn_like=f"%{stn_id}%")

                return {'statusCode': 200, 'headers': headers, 'body': json.dumps({'success': True, 'message': 'Station approved successfully'})}

            # Route 6: POST /api/reject - Admin Reject Station (saves rejection_reason in stations table)
            elif '/reject' in path or '/remove' in path:
                stn_id = body.get('station_id', '')
                if not stn_id:
                    parts = [p for p in path.split('/') if p and p != 'api' and p != 'stations' and p != 'reject' and p != 'remove']
                    stn_id = parts[0] if parts else ''

                admin_id = str(body.get('approved_by', body.get('admin_id', 'usr_admin_hq'))).strip()
                reason = str(body.get('rejection_reason', body.get('reason', 'Rejected by Admin HQ'))).strip()

                con.run("""
                    UPDATE stations
                    SET approval_status = 'rejected',
                        approved_by = :admin_id,
                        rejection_reason = :reason
                    WHERE station_id = :stn_id OR station_id LIKE :stn_like;
                """, admin_id=admin_id, reason=reason, stn_id=stn_id, stn_like=f"%{stn_id}%")

                return {'statusCode': 200, 'headers': headers, 'body': json.dumps({'success': True, 'message': 'Station rejected successfully'})}

            # Route 7: GET /api/stations OR /api/stations/pending
            elif '/stations' in path and http_method == 'GET':
                if '/pending' in path:
                    # Only return pending stations for Admin
                    rows = con.run("""
                        SELECT s.station_id, s.owner_user_id, COALESCE(u.full_name, s.owner_user_id) AS owner_name,
                               COALESCE(u.role_category, 'generalPublic') AS owner_category,
                               s.category, s.instrument_type, s.device_make, s.measurement_location,
                               s.device_photo_url, s.latitude, s.longitude, s.district, s.taluk,
                               s.grama_panchayat, s.village, s.approval_status, s.approved_by,
                               COALESCE(s.rejection_reason, '') AS rejection_reason
                        FROM stations s
                        LEFT JOIN kusers u ON s.owner_user_id = u.user_id
                        WHERE s.approval_status = 'pending'
                        ORDER BY s.created_at DESC;
                    """)
                else:
                    # Return all stations (approved, pending, rejected) with rejection_reason
                    rows = con.run("""
                        SELECT s.station_id, s.owner_user_id, COALESCE(u.full_name, s.owner_user_id) AS owner_name,
                               COALESCE(u.role_category, 'generalPublic') AS owner_category,
                               s.category, s.instrument_type, s.device_make, s.measurement_location,
                               s.device_photo_url, s.latitude, s.longitude, s.district, s.taluk,
                               s.grama_panchayat, s.village, s.approval_status, s.approved_by,
                               COALESCE(s.rejection_reason, '') AS rejection_reason
                        FROM stations s
                        LEFT JOIN kusers u ON s.owner_user_id = u.user_id
                        ORDER BY s.created_at DESC;
                    """)
                cols = ['station_id', 'owner_user_id', 'owner_name', 'owner_category', 'category', 'instrument_type', 'device_make', 'measurement_location', 'device_photo_url', 'latitude', 'longitude', 'district', 'taluk', 'grama_panchayat', 'village', 'approval_status', 'approved_by', 'rejection_reason']
                stations = [dict(zip(cols, r)) for r in rows]
                return {'statusCode': 200, 'headers': headers, 'body': json.dumps({'success': True, 'stations': stations}, default=str)}

            # Route 8: POST /api/stations
            elif '/stations' in path and http_method == 'POST':
                stn_id = str(body.get('station_id') or f"stn_{os.urandom(4).hex()}")
                con.run("""
                    INSERT INTO stations (station_id, owner_user_id, category, instrument_type, device_make, measurement_location, device_photo_url, latitude, longitude, district, taluk, grama_panchayat, village, approval_status, approved_by)
                    VALUES (:stn_id, :owner_user_id, :category, :instrument_type, :device_make, :measurement_location, :device_photo_url, :latitude, :longitude, :district, :taluk, :grama_panchayat, :village, 'pending', '');
                """, stn_id=stn_id, owner_user_id=str(body.get('owner_user_id', 'usr_anon')), category=str(body.get('category', 'manual')),
                     instrument_type=str(body.get('instrument_type', 'Rain Gauge')), device_make=str(body.get('device_make', 'Manual')),
                     measurement_location=str(body.get('measurement_location', '')), device_photo_url=str(body.get('device_photo_url', '')),
                     latitude=float(body.get('latitude', 10.0)), longitude=float(body.get('longitude', 76.0)),
                     district=str(body.get('district', 'Kozhikode')), taluk=str(body.get('taluk', '')),
                     grama_panchayat=str(body.get('grama_panchayat', '')), village=str(body.get('village', '')))
                return {'statusCode': 201, 'headers': headers, 'body': json.dumps({'success': True, 'message': 'Station registered successfully'}, default=str)}

            # Route 9: GET /api/champions
            elif '/champions' in path and http_method == 'GET':
                rows = con.run("""
                    SELECT u.user_id, u.full_name, u.email, u.mobile_number, u.user_role, u.role_category,
                           COALESCE(s.current_streak, 0) as streak_days,
                           COALESCE(s.total_contributions, 0) as total_observations,
                           COALESCE(s.badge, 'BRONZE') as badge_tier
                    FROM kusers u
                    LEFT JOIN volunteer_streaks s ON u.user_id = s.user_id
                    WHERE UPPER(u.user_role) = 'VOLUNTEER' AND LOWER(u.user_id) NOT LIKE '%admin%' AND LOWER(u.role_category) NOT LIKE '%admin%'
                    ORDER BY streak_days DESC, total_observations DESC LIMIT 20;
                """)
                cols = ['user_id', 'full_name', 'email', 'mobile_number', 'user_role', 'role_category', 'streak_days', 'total_observations', 'badge_tier']
                champions = [dict(zip(cols, r)) for r in rows]
                return {'statusCode': 200, 'headers': headers, 'body': json.dumps({'success': True, 'champions': champions}, default=str)}

            # Route 10: GET /api/boundaries
            elif '/boundaries' in path:
                rows = con.run("SELECT id, name, boundary_type, district_name, latitude, longitude FROM administrative_boundaries ORDER BY name ASC;")
                cols = ['id', 'name', 'boundary_type', 'district_name', 'latitude', 'longitude']
                boundaries = [dict(zip(cols, r)) for r in rows]
                return {'statusCode': 200, 'headers': headers, 'body': json.dumps({'success': True, 'boundaries': boundaries}, default=str)}

            return {'statusCode': 200, 'headers': headers, 'body': json.dumps({'success': True, 'message': 'KSDMA AWS Lambda Backend API Active'})}

        finally:
            if con:
                try:
                    con.close()
                except Exception:
                    pass

    except Exception as outer_err:
        return {'statusCode': 500, 'headers': headers, 'body': json.dumps({'success': False, 'error': str(outer_err)})}
