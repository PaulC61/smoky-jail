provider "aws" {
  region = "eu-west-1"
}
data "aws_availability_zones" "available" {
  state = "available"
}
resource "aws_vpc" "BTS_HW_VPC" {
  cidr_block = "192.168.0.0/16"
    tags = {
    Name = "BTS_HW_VPC"
  }
}
resource "aws_subnet" "BTS_HW_SN_PRIVATE" {
  vpc_id     = aws_vpc.BTS_HW_VPC.id
  cidr_block = "192.168.${count.index}.0/24"
  availability_zone = data.aws_availability_zones.available.names[count.index]
  count = 2
  tags = {
    Name = "BTS_HW_SN_PRIVATE_${count.index+1}" 
  }
}
resource "aws_subnet" "BTS_HW_SN_PUBLIC" {
  vpc_id     = aws_vpc.BTS_HW_VPC.id
  cidr_block = "192.168.${count.index+2}.0/24"
  availability_zone = data.aws_availability_zones.available.names[count.index]
  count = 2
  tags = {
    Name = "BTS_HW_SN_PUBLIC_${count.index+1}" 
  }
}
resource "aws_internet_gateway" "BTS_HW_IGW" {
  vpc_id = aws_vpc.BTS_HW_VPC.id
  tags = {
    Name = "BTS_HW_IGW"
  }
}
resource "aws_eip" "BTS_HW_EIP" {
  vpc                       = true
  count = 2
  tags = {
    Name = "BTS_HW_EIP_${count.index+1}"
  }
}
resource "aws_nat_gateway" "BTS_HW_NAT" {
  count = 2
  allocation_id = aws_eip.BTS_HW_EIP[count.index].id
  subnet_id     = aws_subnet.BTS_HW_SN_PUBLIC[count.index].id
  tags = {
    Name = "BTS_HW_NAT_${count.index+1}"
  }
   depends_on = [aws_internet_gateway.BTS_HW_IGW,aws_eip.BTS_HW_EIP]
}
resource "aws_route_table" "BTS_HW_RT_IGW" {
  vpc_id = aws_vpc.BTS_HW_VPC.id
  tags = {
    Name = "BTS_HW_RT_IGW"
  }
}
resource "aws_route_table_association" "BTS_HW_RT_IGW_MAP" {
  count = 2
  route_table_id = aws_route_table.BTS_HW_RT_IGW.id
  subnet_id      = aws_subnet.BTS_HW_SN_PUBLIC[count.index].id
}
resource "aws_route" "BTS_HW_RT_IGW_ROUTE" {
  route_table_id         = aws_route_table.BTS_HW_RT_IGW.id
  gateway_id             = aws_internet_gateway.BTS_HW_IGW.id
  destination_cidr_block = "0.0.0.0/0"
}
resource "aws_route_table" "BTS_HW_RT_NAT" {
  count = 2
  vpc_id = aws_vpc.BTS_HW_VPC.id
  tags = {
    Name = "BTS_HW_RT_NAT"
  }
}
resource "aws_route_table_association" "BTS_HW_RT_NAT_MAP" {
  count = 2
  route_table_id = aws_route_table.BTS_HW_RT_NAT[count.index].id
  subnet_id      = aws_subnet.BTS_HW_SN_PRIVATE[count.index].id
}
resource "aws_route" "BTS_HW_RT_NAT_ROUTE" {
  count = 2
  route_table_id         = aws_route_table.BTS_HW_RT_NAT[count.index].id
  nat_gateway_id         = aws_nat_gateway.BTS_HW_NAT[count.index].id
  destination_cidr_block = "0.0.0.0/0"
}
resource "aws_elb" "BTS_HW_ELB" {
  subnets = [aws_subnet.BTS_HW_SN_PUBLIC[0].id,aws_subnet.BTS_HW_SN_PUBLIC[1].id]

  listener {
    instance_port     = 8000
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }
  tags = {
    Name = "BTS_HW_ELB"
  }
}
resource "aws_launch_configuration" "BTS_HW_LAUNCH" {
  name          = "BTS_HW_LAUNCH"
  image_id      = "ami-0713f98de93617bb4"
  instance_type = "t2.micro"
   lifecycle {
    create_before_destroy = true
  }
}
resource "aws_autoscaling_group" "BTS_HW_AUTOSCALE" {
  name                 = "BTS_HW_AUTOSCALE"
  launch_configuration = aws_launch_configuration.BTS_HW_LAUNCH.id
  vpc_zone_identifier = [aws_subnet.BTS_HW_SN_PUBLIC[0].id,aws_subnet.BTS_HW_SN_PUBLIC[1].id]
  load_balancers = [aws_elb.BTS_HW_ELB.id]
  min_size             = 2
  max_size             = 2
  lifecycle {
    create_before_destroy = true
  }
}