#version 120

varying vec2 texcoord;
varying vec4 vColor;
uniform sampler2D texture; // tekstur blok

void main() {
    vec4 tex = texture2D(texture, texcoord);
    // kalikan warna tekstur dengan vertex color (lighting/tint)
    vec3 lit = tex.rgb * vColor.rgb;
    gl_FragColor = vec4(lit, tex.a);
}
