const amplifyconfig = ''' {
  "UserAgent": "aws-amplify-cli/2.0",
  "Version": "1.0",
  "auth": {
    "plugins": {
      "awsCognitoAuthPlugin": {
        "IdentityManager": {
          "Default": {}
        },
        "CognitoUserPool": {
          "Default": {
            "PoolId": "us-east-1_nvv382tYs",
            "AppClientId": "49bvgnea50gvvs00fts6s1pmml",
            "Region": "us-east-1"
          }
        },
        "Auth": {
          "Default": {
            "authenticationFlowType": "USER_SRP_AUTH",
            "usernameAttributes": ["email", "preferred_username"],
            "signupAttributes": [
              "email", "name", "preferred_username"
            ],
            "passwordProtectionSettings": {
                "passwordPolicyMinLength": 8,
                "passwordPolicyCharacters": []
            },
            "OAuth": {
              "WebDomain": "auth.cloudsensevis.com",
              "AppClientId": "49bvgnea50gvvs00fts6s1pmml",
              "SignInRedirectURI": "http://localhost:3000/home,https://www.cloudsensevis.com/home,https://cloudsensevis.com/home",
              "SignOutRedirectURI": "http://localhost:3000/home,https://www.cloudsensevis.com/home",
              "Scopes": [
                "email",
                "openid",
                "profile",
                "aws.cognito.signin.user.admin"
              ]
            }
          }
        }
      }
    }
  }
}''';
