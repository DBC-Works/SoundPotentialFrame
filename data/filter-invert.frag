uniform sampler2D texture;
uniform ivec2 u_size;
out vec4 o_fragColor;

void main()
{
  vec4 color = texture(texture, gl_FragCoord.xy / u_size);
  o_fragColor = vec4(1 - color.r, 1 - color.g, 1 - color.b, 1);
}