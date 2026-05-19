-- Demo county geofences for admin map visualization
-- Run this after schema/seed setup.

insert into public.geofences (name, description, region, coordinates)
values
  (
    'Nairobi County Demo',
    'Demo boundary for Nairobi county.',
    'Nairobi',
    '[{"lat": -1.220, "lng": 36.760}, {"lat": -1.220, "lng": 36.940}, {"lat": -1.380, "lng": 36.940}, {"lat": -1.380, "lng": 36.760}]'::jsonb
  ),
  (
    'Mombasa County Demo',
    'Demo boundary for Mombasa county.',
    'Mombasa',
    '[{"lat": -3.930, "lng": 39.610}, {"lat": -3.930, "lng": 39.760}, {"lat": -4.120, "lng": 39.760}, {"lat": -4.120, "lng": 39.610}]'::jsonb
  ),
  (
    'Kisumu County Demo',
    'Demo boundary for Kisumu county.',
    'Kisumu',
    '[{"lat": -0.020, "lng": 34.650}, {"lat": -0.020, "lng": 34.860}, {"lat": -0.190, "lng": 34.860}, {"lat": -0.190, "lng": 34.650}]'::jsonb
  ),
  (
    'Nakuru County Demo',
    'Demo boundary for Nakuru county.',
    'Nakuru',
    '[{"lat": -0.130, "lng": 35.950}, {"lat": -0.130, "lng": 36.220}, {"lat": -0.430, "lng": 36.220}, {"lat": -0.430, "lng": 35.950}]'::jsonb
  ),
  (
    'Kiambu County Demo',
    'Demo boundary for Kiambu county.',
    'Kiambu',
    '[{"lat": -1.000, "lng": 36.620}, {"lat": -1.000, "lng": 37.000}, {"lat": -1.280, "lng": 37.000}, {"lat": -1.280, "lng": 36.620}]'::jsonb
  ),
  (
    'Uasin Gishu County Demo',
    'Demo boundary for Uasin Gishu county.',
    'Uasin Gishu',
    '[{"lat": 0.350, "lng": 35.100}, {"lat": 0.350, "lng": 35.450}, {"lat": 0.000, "lng": 35.450}, {"lat": 0.000, "lng": 35.100}]'::jsonb
  );
