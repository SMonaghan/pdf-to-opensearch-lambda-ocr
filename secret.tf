resource "random_string" "os_user" {
	length  = 6
	lower   = true
	special = false
	upper   = false
	numeric = false
}

resource "random_password" "os_password" {
	length           = 16
	special          = true
	override_special = "~!@#$%^&*_-+=`|\\(){}[]:;'<>,.?/"
	min_lower        = 1
	min_upper        = 1
	min_numeric      = 1
	min_special      = 1
}
 
# Creating a AWS secret for database master account (Masteraccoundb)
 
resource "aws_secretsmanager_secret" "os_admin_password" {
	 name_prefix = "OSAdminPassword-"
}
 
# Creating a AWS secret versions for database master account (Masteraccoundb)
 
resource "aws_secretsmanager_secret_version" "os_secret" {
	secret_id = aws_secretsmanager_secret.os_admin_password.id
	secret_string = jsonencode({"username": "${random_string.os_user.result}","password": "${random_password.os_password.result}"})
}