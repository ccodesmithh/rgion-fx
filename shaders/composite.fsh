#version 120

uniform sampler2D colortex0; // hasil dari gbuffers
varying vec2 texcoord;

void main() {
    vec4 color = texture2D(colortex0, texcoord);

    // itung jarak pixel dari tengah layar (0.5, 0.5)
    float dist = distance(texcoord, vec2(0.5));

    // buat faktor gelap: semakin jauh dari tengah = makin gelap
    float vignette = smoothstep(0.4, 0.8, dist);

    // campurkan warna asli dengan vignette (gelap)
    color.rgb *= 1.0 - vignette * 0.6;

    gl_FragColor = color;
}
