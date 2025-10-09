#version 120

varying vec2 texcoord;
varying vec4 vColor;

void main() {
    gl_Position = ftransform();
    texcoord = gl_MultiTexCoord0.st;
    vColor = gl_Color; // bawa vertex color ke fragment
}
