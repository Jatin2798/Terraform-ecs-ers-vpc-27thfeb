variable "aws_region" {
	description = "AWS region"
	type = string
	default = "us-east-1"
}


variable "project_name" {
	default = "Hello-wolrd"
	description = "Project name to be used for tagging"
	type = string
}

variable  "environment" {
	default = "dev"
	type = string
	description = "Environment (dev/stage/prod)"
}



