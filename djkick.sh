#!/bin/bash
# Author: Aurelien Martin
# Bootstrap django project with virtual environement and .env file

# Check if at least 2 arguments are provided
if [ "$#" -lt 2 ]; then
  echo "Usage: $0 project_name database_type (sqlite or pgsql)"
  exit 1
fi

# Assign command line arguments to variables
PROJECT_NAME=$1
DB_TYPE=$2


DJANGO_PROJECT_NAME='project' # Default django project for common practice

# Root dir of project
PROJECT_DIR='projects'
# Create project directory and enter it
mkdir -p $PROJECT_DIR/$PROJECT_NAME && cd $PROJECT_DIR/$PROJECT_NAME

# Create and activate a virtual environment
python3 -m venv .venv
source .venv/bin/activate

# Install Django and python-dotenv
pip install django python-dotenv

# If PostgreSQL is chosen, install psycopg2 as well
if [ "$DB_TYPE" = "pgsql" ]; then
  pip install psycopg2-binary
fi

# Create the Django project in the current directory
django-admin startproject $DJANGO_PROJECT_NAME .

# Navigate back to the root project directory to access manage.py
cd ..

# Update .env file with default and database-specific configurations
cat << EOF > $PROJECT_NAME/.env
DJANGO_SECRET_KEY='your_secret_key_here'
DJANGO_DEBUG=True
DJANGO_ALLOWED_HOSTS=localhost,127.0.0.1
DJANGO_TIME_ZONE=UTC
EOF

if [ "$DB_TYPE" = "pgsql" ]; then
  cat << EOF >> $PROJECT_NAME/.env
DJANGO_DB_ENGINE=django.db.backends.postgresql
DJANGO_DB_NAME=your_database_name
DJANGO_DB_USER=your_username
DJANGO_DB_PASSWORD=your_password
DJANGO_DB_HOST=localhost
EOF

# Supprimer le bloc DATABASES existant
# sed -i "/DATABASES = {/,/}/d" $PROJECT_NAME/$DJANGO_PROJECT_NAME/settings.py

awk '
BEGIN { depth=0; }
/DATABASES = \{/ { depth=1; next; }
depth > 0 && /\{/ { depth++; next; }
depth > 0 && /\}/ { depth--; if (depth == 0) next; }
depth == 0 { print; }
' $PROJECT_NAME/$DJANGO_PROJECT_NAME/settings.py > $PROJECT_NAME/$DJANGO_PROJECT_NAME/temp_settings.py && mv $PROJECT_NAME/$DJANGO_PROJECT_NAME/temp_settings.py $PROJECT_NAME/$DJANGO_PROJECT_NAME/settings.py


# Ajouter le nouveau bloc DATABASES pour PostgreSQL
cat << EOF >> $PROJECT_NAME/$DJANGO_PROJECT_NAME/settings.py
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql',
        'NAME': os.getenv('DJANGO_DB_NAME', 'your_database_name'),
        'USER': os.getenv('DJANGO_DB_USER', 'your_username'),
        'PASSWORD': os.getenv('DJANGO_DB_PASSWORD', 'your_password'),
        'HOST': os.getenv('DJANGO_DB_HOST', 'localhost'),
        'PORT': os.getenv('DJANGO_DB_PORT', '5432'),
     }
}
EOF


else
  cat << EOF >> $PROJECT_NAME/.env
DJANGO_DB_ENGINE=django.db.backends.sqlite3
DJANGO_DB_NAME=db.sqlite3
EOF
fi

# Modify settings.py to use environment variables
cd $PROJECT_NAME/$DJANGO_PROJECT_NAME
sed -i "s/SECRET_KEY = .*/SECRET_KEY = os.getenv('DJANGO_SECRET_KEY', 'change_me')/" settings.py
sed -i "s/DEBUG = .*/DEBUG = os.getenv('DJANGO_DEBUG', 'False') == 'True'/" settings.py
sed -i "s/ALLOWED_HOSTS = .*/ALLOWED_HOSTS = os.getenv('DJANGO_ALLOWED_HOSTS', '').split(',')/" settings.py
sed -i "s/TIME_ZONE = .*/TIME_ZONE = os.getenv('DJANGO_TIME_ZONE', 'UTC')/" settings.py
cd ../..

# Add python-dotenv imports at the beginning of settings.py and manage.py
sed -i "1i import os\nfrom dotenv import load_dotenv\nload_dotenv()\n\n" $PROJECT_NAME/manage.py
sed -i "1i import os\nfrom dotenv import load_dotenv\nload_dotenv()\n\n" $PROJECT_NAME/$DJANGO_PROJECT_NAME/settings.py

if [ "$DB_TYPE" = "pgsql" ]; then
echo "SQL to create related psql role and database"
echo ""
echo "CREATE ROLE user_dev WITH LOGIN PASSWORD 'xxxxx';"
echo "CREATE DATABASE db_name OWNER user_dev;"
echo "GRANT ALL PRIVILEGES ON DATABASE db_name TO user_dev;"
echo ""
echo "Django project $PROJECT_NAME configured successfully!"
fi
