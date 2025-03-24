yum update -y
amazon-linux-extras install docker -y
yum install amazon-efs-utils -y
systemctl start docker.service
systemctl enable docker.service
until curl -fL -o /usr/local/bin/docker-compose \
  "https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64"; do
  sleep 5
done
chmod +x /usr/local/bin/docker-compose
ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose
EFS_ID=$(aws ssm get-parameter --name efs-id --with-decryption --region=us-east-1 --query "Parameter.Value" --output=text)
export EFS_ID
DB_HOST=$(aws ssm get-parameter --name db-host --with-decryption --region=us-east-1 --query "Parameter.Value" --output=text)
export DB_HOST
DB_NAME=$(aws ssm get-parameter --name db-name --with-decryption --region=us-east-1 --query "Parameter.Value" --output=text)
export DB_NAME
DB_USER=$(aws ssm get-parameter --name db-user --with-decryption --region=us-east-1 --query "Parameter.Value" --output=text)
export DB_USER
DB_PASSWORD=$(aws ssm get-parameter --name db-password --with-decryption --region=us-east-1 --query "Parameter.Value" --output=text)
export DB_PASSWORD
mkdir -p /mnt/efs/wordpress
mount -t efs -o tls $EFS_ID:/ /mnt/efs/wordpress
grep -qxF "$EFS_ID:/ /mnt/efs/wordpress efs _netdev,tls,noresvport 0 0" /etc/fstab || echo "$EFS_ID:/ /mnt/efs/wordpress efs _netdev,tls,noresvport 0 0" | tee -a /etc/fstab > /dev/null
echo "services:
  wordpress:
    image: wordpress:latest
    container_name: wordpress
    restart: always
    ports:
      - '80:80'
    environment:
      WORDPRESS_DB_HOST: "\$DB_HOST"
      WORDPRESS_DB_USER: "\$DB_USER"
      WORDPRESS_DB_PASSWORD: "\$DB_PASSWORD"
      WORDPRESS_DB_NAME: "\$DB_NAME"
    volumes:
      - /mnt/efs/wordpress:/var/www/html" >> /home/ec2-user/docker-compose.yml
docker-compose -f /home/ec2-user/docker-compose.yml up