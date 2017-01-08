#version 120

//////////////////////////////ADJUSTABLE VARIABLES
//////////////////////////////ADJUSTABLE VARIABLES
//////////////////////////////ADJUSTABLE VARIABLES

#define PARALLAX_WATER //Gives water waves a 3D look
#define WATER_QUALITY 5 //[1 2 3 4 5] higher numbers gives better looking water

	vec4 watercolor = vec4(vec3(0.05, 0.3, 0.5), 0.25); 	//water color and opacity (r,g,b,opacity)

//////////////////////////////END OF ADJUSTABLE VARIABLES
//////////////////////////////END OF ADJUSTABLE VARIABLES
//////////////////////////////END OF ADJUSTABLE VARIABLES

varying vec4 color;
varying vec4 texcoord;
varying vec4 lmcoord;
varying vec3 binormal;
varying vec3 normal;
varying vec3 tangent;
varying vec3 viewVector;
varying vec3 wpos;
varying float mat;
varying float iswater;
varying float viewdistance;
varying vec4 verts;

uniform sampler2D texture;
uniform sampler2D noisetex;
uniform float frameTimeCounter;

float istransparent = float(mat > 0.4 && mat < 0.42);

float waveZ = mix(3.0,0.25,1-istransparent);
float waveM = mix(0.0,2.0,1-istransparent);
float waveS = mix(0.1,1.5,1-istransparent);


#include "lib/waterBump.glsl"

vec3 stokes(in float ka, in vec3 k, in vec3 g) {
    // ka = wave steepness, k = displacements, g = gradients / wave number
    float theta = k.x + k.z + k.t;
    float s = ka * (sin(theta) + ka * sin(2.0f * theta));
    return vec3(s * g.x, s * g.z, g.t);  // (-deta/dx, -deta/dz, scale)
}

vec3 waves1(in float bumpmult) {
    float scale = 8.0f / (viewdistance * viewdistance);
    vec3 gg = vec3(scale, 3600.0f, scale);
    vec3 gk = vec3(viewdistance * 6.0f, frameTimeCounter * -6.0f, 0.0f);
    vec3 gwave = stokes(10.0f*bumpmult*10.0, gk, gg);
    return normalize(gwave);
}

float smoothStep(in float edge0, in float edge1, in float x) {
    float t = clamp((x - edge0) / (edge1 - edge0), 0.0f, 1.0f);
    return t * t * (3.0f - 2.0f * t);
}

#ifdef PARALLAX_WATER

vec2 paralaxCoords(vec3 pos, vec3 tangentVector, float istransparent) {

	float waterHeight = getWaterBump(pos.xz - pos.y, istransparent) * 5.0;

	vec3 paralaxCoord = vec3(0.0, 0.0, 1.0);
	vec3 stepSize = vec3(waveS, waveS, 1.0);
	vec3 step = tangentVector * stepSize;

	for (int i = 0; waterHeight < paralaxCoord.z && i < 15; i++) {
		paralaxCoord.xy = mix(paralaxCoord.xy, paralaxCoord.xy + step.xy, clamp((paralaxCoord.z - waterHeight) / (stepSize.z * 0.2f / (-tangentVector.z + 0.05f)), 0.0f, 1.0));
		paralaxCoord.z += step.z;
		vec3 paralaxPosition = pos + vec3(paralaxCoord.x, 0.0f, paralaxCoord.y);
		waterHeight = getWaterBump(paralaxPosition.xz - paralaxPosition.y, istransparent) * 0.0;
	}
	pos += vec3(paralaxCoord.x, 0.0f, paralaxCoord.y);
	return pos.xz - pos.y;
}

#endif


//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////

void main() {

	vec4 tex;

	if (iswater < 0.9)
		tex = texture2D(texture, vec2(texcoord.st))*color;
	else
	tex = vec4((watercolor).rgb,watercolor.a);

	#ifdef USE_WATER_TEXTURE
	tex = texture2D(texture, texcoord.xy)*color;
	#endif


	vec3 posxz = wpos.xyz;

	vec4 frag2;
		frag2 = vec4((normal) * 0.5f + 0.5f, 1.0f);
	vec4 frag3;
		frag3 = vec4((normal) * 0.5f + 0.5f, 1.0f);


	float bumpmult = 0.1;

	mat3 tbnMatrix = mat3(tangent.x, binormal.x, normal.x,
						tangent.y, binormal.y, normal.y,
						tangent.z, binormal.z, normal.z);

	#ifdef PARALLAX_WATER
		vec4 modelView = gl_ModelViewMatrix * verts;
		vec3 tangentVector = normalize(tbnMatrix * modelView.xyz);

		posxz.xz = paralaxCoords(posxz, tangentVector, istransparent);
	#endif

	vec3 bump = waterNormals(posxz.xz - posxz.y, istransparent);

	bump = bump * vec3(bumpmult, bumpmult, bumpmult) + vec3(0.0f, 0.0f, 1.0f - bumpmult);

	frag2 = vec4(normalize(bump * tbnMatrix) * 0.5 + 0.5, 1.0);
	frag3 = vec4(normalize(waves1(0.05) * tbnMatrix) * 0.5 + 0.5, 1.0);


/* DRAWBUFFERS:543 */

	gl_FragData[0] = tex;
	gl_FragData[1] = vec4(lmcoord.t, mat, lmcoord.s, 1.0);
	gl_FragData[2] = vec4(frag2);
}
