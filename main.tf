data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

resource "aws_security_group" "pritunl" {
  name        = "${var.resource_name_prefix}-vpn"
  description = "${var.resource_name_prefix}-vpn"
  vpc_id      = "${var.vpc_id}"

  # SSH access
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.internal_cidrs
  }

  # HTTPS access
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.internal_cidrs
  }

  # VPN WAN access
  ingress {
    from_port   = 10000
    to_port     = 19999
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # ICMP
  ingress {
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = var.internal_cidrs
  }

  # outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = "${
    merge(
      map("Name", format("%s-%s", var.resource_name_prefix, "vpn")),
      var.tags,
    )
  }"
}

resource "aws_security_group" "allow_from_office" {
  name        = "${var.resource_name_prefix}-whitelist"
  description = "Allows SSH connections and HTTP(s) connections from office"
  vpc_id      = "${var.vpc_id}"

  # SSH access
  ingress {
    description = "Allow SSH access from select CIDRs"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.whitelist
  }

  # HTTPS access
  ingress {
    description = "Allow HTTPS access from select CIDRs"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.whitelist
  }

  # ICMP
  ingress {
    description = "Allow ICMPv4 from select CIDRs"
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = var.whitelist
  }

  # outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = "${
    merge(
      map("Name", format("%s-%s", var.resource_name_prefix, "whitelist")),
      var.tags,
    )
  }"
}

data "aws_ami" "oracle" {
  most_recent = true

  filter {
    name   = "name"
    values = ["OL7.6-x86_64-HVM-2019-01-29"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["131827586825"] # Canonical
}

resource "aws_instance" "pritunl" {
  ami           = "${data.aws_ami.oracle.id}"
  instance_type = "${var.instance_type}"
  key_name      = "${var.aws_key_name}"
  user_data     = "${file("${path.module}/provision.sh")}"

  vpc_security_group_ids = [
    "${aws_security_group.pritunl.id}",
    "${aws_security_group.allow_from_office.id}",
  ]

  subnet_id = "${var.public_subnet_id}"

  tags = "${
    merge(
      map("Name", format("%s-%s", var.resource_name_prefix, "vpn")),
      var.tags,
    )
  }"

}

# resource "aws_route53_record" "pritunl-www" {
#   zone_id = "${var.route53_zoneid}"
#   name    = "${var.domain_name}"
#   type    = "A"
#   ttl     = "300"
#   records = ["${aws_instance.pritunl.public_ip}"]
# }


