#version 120

uniform sampler2D colortex0; // hasil dari composite pass
varying vec2 texcoord;

void main() {
    // Ambil warna dari composite pass dan tampilkan langsung
    vec4 color = texture2D(colortex0, texcoord);
    gl_FragColor = color;
}
