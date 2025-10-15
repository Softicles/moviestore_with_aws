from django.shortcuts import render

# Create your views here.
def index(request):
    template_data = {}
    template_data['title'] = 'Movies Store'
    return render(request, 'home/index.html', {'template_data': template_data})

def about(request):
    template_data = {}
    template_data['title'] = 'About'
    return render(request, 'home/about.html', {'template_data': template_data})

def login(request):
    template_data = {}
    template_data['title'] = 'Login'
    return render(request, 'home/login.html', {'template_data': template_data})

def signup(request):
    template_data = {}
    template_data['title'] = 'signup'
    return render(request, 'home/signup.html', {'template_data': template_data})
