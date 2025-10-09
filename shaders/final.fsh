#version 120

uniform sampler2D colortex0; // hasil dari composite pass
varying vec2 texcoord;
uniform vec2 viewSize; // ukuran layar dari engine

void main() {
    // Ambil warna dari composite pass dan tampilkan langsung
    vec4 color = texture2D(colortex0, texcoord);
    
    // --- VIGNETTE EFFECT ---
    vec2 uv = gl_FragCoord.xy / viewSize;      // Normalisasi koordinat layar
    vec2 centered = uv - 0.5;                  // Pusatkan ke tengah
    centered.x *= viewSize.x / viewSize.y;     // Koreksi rasio aspek
    float dist = length(centered);             // Jarak dari pusat layar

    // Parameter efek vignette
    float inner = 0.4;    // radius tengah
    float outer = 0.8;    // radius tepi
    float strength = 0.6; // seberapa kuat efek gelap

    // Transisi lembut dari tengah ke tepi
    float vignette = smoothstep(inner, outer, dist);

    // Campurkan ke warna akhir
    color *= mix(1.0, 1.0 - vignette, strength);

    gl_FragColor = color;
}
