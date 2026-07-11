path = r'D:\Sejal_Intern\Updated_CloudSense\Cloud_Sense_WebApp\android\app\src\main\kotlin\com\example\cloud_sense_webapp\CloudSenseWidgetProvider.kt'
data = open(path, 'rb').read()
new_data = data.replace(b'String.format("%.2f\xc2\xb0C", temperature)', b'String.format("%.2f\u00B0C", temperature)')
open(path, 'wb').write(new_data)
print('Replaced successfully')
