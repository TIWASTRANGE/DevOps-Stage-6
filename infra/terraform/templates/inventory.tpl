[todo_servers]
app_server ansible_host=${server_ip} ansible_user=${ssh_user} ansible_ssh_private_key_file=../terraform/keys/id_rsa ansible_python_interpreter=/usr/bin/python3

[todo_servers:vars]
ansible_ssh_common_args='-o StrictHostKeyChecking=no'
