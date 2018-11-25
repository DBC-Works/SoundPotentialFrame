uniform sampler2D texture;
uniform ivec2 u_size;
out vec4 o_fragColor;

void main()
{
  vec4 color = texture(texture, gl_FragCoord.xy / u_size);
  float grayScale = ((color.r * 0.109375) + (color.g * 0.30078125) + (color.b * 0.58984375));
  o_fragColor = vec4(grayScale, grayScale, grayScale, 1);
}