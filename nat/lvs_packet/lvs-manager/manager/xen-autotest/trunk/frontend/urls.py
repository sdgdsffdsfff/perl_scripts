from django.conf.urls import defaults
from django.conf import settings

# The next two lines enable the admin and load each admin.py file:
from django.contrib import admin
admin.autodiscover()

RE_PREFIX = '^' + settings.URL_PREFIX
PLANNER_RE_PREFIX = '^' + settings.PLANNER_URL_PREFIX

handler500 = 'frontend.afe.views.handler500'

urlpatterns = defaults.patterns(
        '',
        (RE_PREFIX + r'admin/(.*)', admin.site.root),
        (RE_PREFIX, defaults.include('frontend.afe.urls')),
        (PLANNER_RE_PREFIX, defaults.include('frontend.planner.urls')),
    )

debug_patterns = defaults.patterns(
        '',
        # redirect /tko and /results to local apache server
        (r'^(?P<path>(tko|results)/.*)$',
         'frontend.afe.views.redirect_with_extra_data',
         {'url': 'http://%(server_name)s/%(path)s?%(getdata)s'}),
    )

if settings.DEBUG:
    urlpatterns += debug_patterns