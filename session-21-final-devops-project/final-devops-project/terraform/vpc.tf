locals {
  # 10.40.0.0/16 -> public 10.40.1.0/24, 10.40.2.0/24 ; private 10.40.11.0/24, 10.40.12.0/24
  public_cidrs  = { for i, az in var.azs : az => cidrsubnet(var.vpc_cidr, 8, i + 1) }
  private_cidrs = { for i, az in var.azs : az => cidrsubnet(var.vpc_cidr, 8, i + 11) }
}

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true # required by EKS
  tags                 = { Name = "${var.name}-vpc" }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${var.name}-igw" }
}

resource "aws_subnet" "public" {
  for_each                = local.public_cidrs
  vpc_id                  = aws_vpc.main.id
  cidr_block              = each.value
  availability_zone       = "${var.aws_region}${each.key}"
  map_public_ip_on_launch = true
  tags = {
    Name                     = "${var.name}-public-${each.key}"
    "kubernetes.io/role/elb" = "1" # internet-facing load balancers go here
  }
}

resource "aws_subnet" "private" {
  for_each          = local.private_cidrs
  vpc_id            = aws_vpc.main.id
  cidr_block        = each.value
  availability_zone = "${var.aws_region}${each.key}"
  tags = {
    Name                              = "${var.name}-private-${each.key}"
    "kubernetes.io/role/internal-elb" = "1"
  }
}

# one NAT gateway (cost-conscious; production would use one per AZ)
resource "aws_eip" "nat" {
  domain = "vpc"
  tags   = { Name = "${var.name}-nat-eip" }
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[var.azs[0]].id
  tags          = { Name = "${var.name}-nat" }
  depends_on    = [aws_internet_gateway.main]
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
  tags = { Name = "${var.name}-public-rt" }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }
  tags = { Name = "${var.name}-private-rt" }
}

resource "aws_route_table_association" "public" {
  for_each       = aws_subnet.public
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  for_each       = aws_subnet.private
  subnet_id      = each.value.id
  route_table_id = aws_route_table.private.id
}
