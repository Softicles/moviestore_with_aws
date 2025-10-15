from django.urls import path
from . import views
urlpatterns = [
    path('', views.index, name='home.index'),
    path('about', views.about, name='home.about'),
    path('signup', views.signup, name='home.signup'),
    path('login', views.login, name='home.login'),

]