output "control_plane_instance_id" {
  value = aws_instance.control_plane.id
}

output "worker_instance_id" {
  value = aws_instance.worker.id
}

output "control_plane_private_ip" {
  value = aws_instance.control_plane.private_ip
}

output "worker_private_ip" {
  value = aws_instance.worker.private_ip
}

output "vpc_a_id" {
  value = aws_vpc.vpc_a.id
}

output "vpc_b_id" {
  value = aws_vpc.vpc_b.id
}

output "peering_connection_id" {
  value = aws_vpc_peering_connection.peer.id
}
