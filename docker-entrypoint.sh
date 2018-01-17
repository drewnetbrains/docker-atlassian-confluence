#!/bin/bash

# check if the `server.xml` file has been changed since the creation of this
# Docker image. If the file has been changed the entrypoint script will not
# perform modifications to the configuration file.
if [ "$(stat -c "%Y" "${CONF_INSTALL}/conf/server.xml")" -eq "0" ]; then
  if [ -n "${X_PROXY_NAME}" ]; then
    xmlstarlet ed --inplace --pf --ps --insert '//Connector[@port="8090"]' --type "attr" --name "proxyName" --value "${X_PROXY_NAME}" "${CONF_INSTALL}/conf/server.xml"
  fi
  if [ -n "${X_PROXY_PORT}" ]; then
    xmlstarlet ed --inplace --pf --ps --insert '//Connector[@port="8090"]' --type "attr" --name "proxyPort" --value "${X_PROXY_PORT}" "${CONF_INSTALL}/conf/server.xml"
  fi
  if [ -n "${X_PROXY_SCHEME}" ]; then
    xmlstarlet ed --inplace --pf --ps --insert '//Connector[@port="8090"]' --type "attr" --name "scheme" --value "${X_PROXY_SCHEME}" "${CONF_INSTALL}/conf/server.xml"
  fi
  if [ -n "${X_PROXY_SECURE}" ]; then
    xmlstarlet ed --inplace --pf --ps --insert '//Connector[@port="8090"]' --type "attr" --name "secure" --value "${X_PROXY_SECURE}" "${CONF_INSTALL}/conf/server.xml"
  fi
  if [ -n "${X_PATH}" ]; then
    xmlstarlet ed --inplace --pf --ps --update '//Context[@docBase="../confluence"]/@path' --value "${X_PATH}" "${CONF_INSTALL}/conf/server.xml"
  fi
fi

if [ -f "${CERTIFICATE}" ]; then
  keytool -noprompt -storepass changeit -keystore ${JAVA_CACERTS} -import -file ${CERTIFICATE} -alias CompanyCA
fi

# Download Atlassian required config files from s3
/usr/bin/aws s3 cp s3://fathom-atlassian-ecs/${ENVIRONMENT}/confluence/confluence.cfg.xml ${CONF_HOME}

# Pull Atlassian secrets from parameter store
AZ=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)
AWSREGION=${AZ::-1}

DATABASE_ENDPOINT=$(aws ssm get-parameters --names "${ENVIRONMENT}.atlassian.rds.db_host" --region ${AWSREGION} --with-decryption --query Parameters[0].Value --output text)
DATABASE_USER=$(aws ssm get-parameters --names "${ENVIRONMENT}.atlassian.rds.db_user" --region ${AWSREGION} --with-decryption --query Parameters[0].Value --output text)
DATABASE_PASSWORD=$(aws ssm get-parameters --names "${ENVIRONMENT}.atlassian.rds.password" --region ${AWSREGION} --with-decryption --query Parameters[0].Value --output text)
DATABASE_NAME=${DATABASE_NAME}

/bin/sed -i -e "s/DATABASE_ENDPOINT/$DATABASE_ENDPOINT/" \
            -e "s/DATABASE_USER/$DATABASE_USER/" \
            -e "s/DATABASE_PASSWORD/$DATABASE_PASSWORD/" \
            -e "s/DATABASE_NAME/$DATABASE_NAME/" confluence.cfg.xml

exec "$@"
