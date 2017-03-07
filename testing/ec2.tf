variable "team" {}
variable "package" {}
variable "package_version" {}

variable "instance_type" {
  default = "m3.medium" 
}

variable "environment" {
    default = "dev"
}

variable "count" {
    default = 1
}

provider "aws" {
    region = "us-east-1"
}

data "aws_ami" "test_ami" {
  most_recent = true
  filter {
    name = "name"
    values = ["base64-all-chartboost-ubuntu"]
  }
}

resource "aws_instance" "test_instance" {
    ami = "${data.aws_ami.test_ami.id}"
    count = "${var.count}"
    instance_type = "${var.instance_type}"
    iam_instance_profile = "BaseIAMRole"
    key_name = "devops-20151021"
    subnet_id = "subnet-6f5e1e36"
    vpc_security_group_ids = ["sg-2160b946"]
    tags {
        Name = "${var.package}-${var.package_version}"
        Environment = "${var.environment}"
        Team = "${var.team}"
    }
    provisioner "remote-exec" {
        inline = [
          "sudo apt-get update",
          "sudo apt-get install -y ${var.package}=${var.package_version}"
        ]
        connection {
          type = "ssh"
          user = "ubuntu"
          private_key = "${file("~/.ssh/devops.pem")}"
        }
    }
}

resource "aws_route53_record" "test_cname_public" {
    # The number of times this aws_instance will be created.
    count = "${var.count}"
    zone_id = "ZWHMDJZPG8AR"
    name = "${element(aws_instance.test_instance.*.tags.Name, count.index)}"
    type = "A"
    ttl = "60"
    records = ["${element(aws_instance.test_instance.*.public_ip, count.index)}"]
}

resource "aws_route53_record" "test_cname_private" {
    # The number of times this aws_instance will be created.
    count = "${var.count}"
    zone_id = "Z2TENC28OZNAVH"
    name = "${element(aws_instance.test_instance.*.tags.Name, count.index)}"
    type = "A"
    ttl = "60"
    records = ["${element(aws_instance.test_instance.*.private_ip, count.index)}"]
}
