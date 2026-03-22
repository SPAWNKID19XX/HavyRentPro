from .base import *  # noqa: F403   
SECRET_KEY = "test-secret-key"
DEBUG = True
ALLOWED_HOSTS = ["*"]
DATABASES = {                                                                                      
    "default": {                                                                                   
        "ENGINE": "django.db.backends.postgresql_psycopg2",
        "NAME": "hrp",                                     
        "USER": "postgres",
        "PASSWORD": "postgres",
        "HOST": "localhost",                                                                       
        "PORT": "5432",                                                                            
    }                                                                                              
}    