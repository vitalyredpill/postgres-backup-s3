#! /bin/sh

set -eu
set -o pipefail

source ./env.sh

if [ "" != "$MYSQL_DATABASE" ]; then
  echo "Creating backup of $MYSQL_DATABASE database..."
  mysqldump --no-tablespaces --opt -h ${MYSQL_HOST} -u ${MYSQL_USER} --port=$MYSQL_PORT -p${MYSQL_PASSWORD} ${MYSQL_DATABASE} $MYSQL_DUMP_EXTRA_OPTS > db.dump
  DATABASE=$MYSQL_DATABASE
else
  echo "Creating backup of $POSTGRES_DATABASE database..."
  pg_dump --format=custom \
          -h $POSTGRES_HOST \
          -p $POSTGRES_PORT \
          -U $POSTGRES_USER \
          -d $POSTGRES_DATABASE \
          $PGDUMP_EXTRA_OPTS \
          > db.dump
  DATABASE=$POSTGRES_DATABASE
fi;

timestamp=$(date +"%Y-%m-%dT%H:%M:%S")
s3_uri_base="s3://${S3_BUCKET}/${S3_PREFIX}/${DATABASE}_${timestamp}.dump"

if [ -n "$PASSPHRASE" ]; then
  echo "Encrypting backup..."
  gpg --symmetric --batch --passphrase "$PASSPHRASE" db.dump
  rm db.dump
  local_file="db.dump.gpg"
  s3_uri="${s3_uri_base}.gpg"
else
  local_file="db.dump"
  s3_uri="$s3_uri_base"
fi

echo "Creating bucket $S3_BUCKET if not exists..."
aws $aws_args s3 mb s3://$S3_BUCKET || true

echo "Uploading backup to $S3_BUCKET..."
aws $aws_args s3 cp "$local_file" "$s3_uri"
rm "$local_file"

echo "Backup complete."

if [ -n "$BACKUP_KEEP_DAYS" ]; then
  sec=$((86400*BACKUP_KEEP_DAYS))
  date_from_remove=$(date -d "@$(($(date +%s) - sec))" +%Y-%m-%d)
  backups_query="Contents[?LastModified<='${date_from_remove} 00:00:00'].{Key: Key}"

  echo "Removing old backups from $S3_BUCKET..."
  aws $aws_args s3api list-objects \
    --bucket "${S3_BUCKET}" \
    --prefix "${S3_PREFIX}" \
    --query "${backups_query}" \
    --output text \
    | xargs -n1 -t -I 'KEY' aws $aws_args s3 rm s3://"${S3_BUCKET}"/'KEY'
  echo "Removal complete."
fi
