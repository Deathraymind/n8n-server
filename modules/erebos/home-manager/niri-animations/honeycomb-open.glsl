// niri-animations/window-open.glsl

#define ROOT_THREE 1.73205080757

float round_value(float value) {
  return floor(value + 0.5);
}

vec2 round_to_hex(vec2 axial_coords) {
  float x = axial_coords.x;
  float z = axial_coords.y;
  float y = - x - z;
  float r_x = round_value(x);
  float r_y = round_value(y);
  float r_z = round_value(z);
  float diff_x = abs(r_x - x);
  float diff_y = abs(r_y - y);
  float diff_z = abs(r_z - z);

  if( diff_x > diff_y && diff_x > diff_z) {
    r_x = - r_y - r_z;
  }
  else if( diff_y > diff_z ) {
    r_y = - r_x - r_z;
  }
  else {
    r_z = - r_y - r_x;
  }
  return vec2(r_x, r_z);
}

vec2 get_axial_coords(vec2 coords, float size) {
  float q_axial = coords.x * (2.0 / 3.0);
  q_axial /= size;
  float r_axial = (-coords.x / 3.0) + (ROOT_THREE / 3.0) * coords.y;
  r_axial /= size;
  return vec2(q_axial, r_axial);
}

vec2 get_normal_coords_of_hex_center(vec2 axial_coords, float size) {
  float q_axial = axial_coords.x;
  float r_axial = axial_coords.y;
  float x = q_axial * (3.0 / 2.0);
  x *= size;
  float y = ROOT_THREE * (r_axial + (q_axial * 0.5));
  y *= size;
  return vec2(x,y);
}

vec4 honeycomb_open(vec3 coords_geo, vec3 size_geo){
  float progress = niri_clamped_progress;
  float aspect_ratio = size_geo.x / size_geo.y;
  vec2 coords = coords_geo.xy;
  vec2 normalized_coords = vec2(coords.x * aspect_ratio, coords.y);
  vec2 normalized_center = vec2(0.5 * aspect_ratio, 0.5);

  float hex_size = 0.02 + (niri_random_seed / 20.0);
  float unit_size = max(hex_size, 0.01);

  vec2 axial_coords = get_axial_coords(normalized_coords, unit_size);
  vec2 nearest_hex = round_to_hex(axial_coords);
  vec2 hex_center = get_normal_coords_of_hex_center(nearest_hex, unit_size);
  float hex_dist = distance(hex_center, normalized_center);
  float max_reveal_radius = length(normalized_center) * 1.25;
  float soft_edge_width = 0.15;
  float wave_radius = progress * (max_reveal_radius + soft_edge_width);
  float mask = smoothstep((wave_radius - soft_edge_width), wave_radius, hex_dist);

  vec3 coords_tex = niri_geo_to_tex * coords_geo;
  vec4 color = texture2D(niri_tex, coords_tex.st);
  color *= (1.0 - mask);
  return color;
}

vec4 open_color(vec3 coords_geo, vec3 size_geo) {
  return honeycomb_open(coords_geo, size_geo);
}
