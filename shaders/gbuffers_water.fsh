#version 120

//////////////////////////////ADJUSTABLE VARIABLES
//////////////////////////////ADJUSTABLE VARIABLES
//////////////////////////////ADJUSTABLE VARIABLES

#define PARALLAX_WATER //Gives water waves a 3D look
#define WATER_QUALITY 5 //[2 3 4 5] higher numbers gives better looking water

	vec4 watercolor = vec4(0.05, 0.5, 0.9, 0.25); 	//water color and opacity (r,g,b,opacity)

//////////////////////////////END OF ADJUSTABLE VARIABLES
//////////////////////////////END OF ADJUSTABLE VARIABLES
//////////////////////////////END OF ADJUSTABLE VARIABLES

varying vec4 color;
varying vec4 texcoord;
varying vec4 lmcoord;
varying vec3 binormal;
varying vec3 normal;
varying vec3 tangent;
varying vec3 wpos;
varying float mat;
varying float iswater;
varying float viewdistance;
varying vec4 verts;

uniform sampler2D texture;
uniform float frameTimeCounter;

float istransparent = float(mat > 0.4 && mat < 0.42);
float ice = float(mat > 0.09 && mat < 0.11);

float waveZ = mix(mix(3.0,0.25,1-istransparent), 8.0, ice);
float waveM = mix(0.0,2.0,1-istransparent+ice);
float waveS = mix(0.1,1.0,1-istransparent+ice);

vec4 cubic(float x)
{
    float x2 = x * x;
    float x3 = x2 * x;
    vec4 w;
    w.x =   -x3 + 3*x2 - 3*x + 1;
    w.y =  3*x3 - 6*x2       + 4;
    w.z = -3*x3 + 3*x2 + 3*x + 1;
    w.w =  x3;
    return w / 6.f;
}

vec4 BicubicTexture(in sampler2D tex, in vec2 coord)
{
	vec2 resolution = vec2(256);

	coord *= resolution;

	float fx = fract(coord.x);
    float fy = fract(coord.y);
    coord.x -= fx;
    coord.y -= fy;

    vec4 xcubic = cubic(fx);
    vec4 ycubic = cubic(fy);

    vec4 c = vec4(coord.x - 0.5, coord.x + 1.5, coord.y - 0.5, coord.y + 1.5);
    vec4 s = vec4(xcubic.x + xcubic.y, xcubic.z + xcubic.w, ycubic.x + ycubic.y, ycubic.z + ycubic.w);
    vec4 offset = c + vec4(xcubic.y, xcubic.w, ycubic.y, ycubic.w) / s;

    vec4 sample0 = texture2D(tex, vec2(offset.x, offset.z) / resolution);
    vec4 sample1 = texture2D(tex, vec2(offset.y, offset.z) / resolution);
    vec4 sample2 = texture2D(tex, vec2(offset.x, offset.w) / resolution);
    vec4 sample3 = texture2D(tex, vec2(offset.y, offset.w) / resolution);

    float sx = s.x / (s.x + s.y);
    float sy = s.z / (s.z + s.w);

    return mix( mix(sample3, sample2, sx), mix(sample1, sample0, sx), sy);
}

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

vec2 paralaxCoords(vec3 pos, vec3 tangentVector) {

	float waterHeight = getWaterBump(pos.xz - pos.y) * 5.0;

	vec3 paralaxCoord = vec3(0.0, 0.0, 1.0);
	vec3 stepSize = vec3(waveS, waveS, 1.0);
	vec3 step = tangentVector * stepSize;

	for (int i = 0; waterHeight < paralaxCoord.z && i < 15; i++) {
		paralaxCoord.xy = mix(paralaxCoord.xy, paralaxCoord.xy + step.xy, clamp((paralaxCoord.z - waterHeight) / (stepSize.z * 0.2f / (-tangentVector.z + 0.05f)), 0.0f, 1.0));
		paralaxCoord.z += step.z;
		vec3 paralaxPosition = pos + vec3(paralaxCoord.x, 0.0f, paralaxCoord.y);
		waterHeight = getWaterBump(paralaxPosition.xz - paralaxPosition.y) * 0.0;
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

	vec4 albedo;
	if (iswater < 0.9){
		albedo = texture2D(texture, texcoord.st);
	}else{
		albedo = watercolor;
	}

	#ifdef USE_WATER_TEXTURE
	albedo = texture2D(texture, texcoord.xy)*color;
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

		posxz.xz = paralaxCoords(posxz, tangentVector);
	#endif

	vec3 bump = waterNormals(posxz.xz - posxz.y, istransparent);

	bump = bump * vec3(bumpmult, bumpmult, bumpmult) + vec3(0.0f, 0.0f, 1.0f - bumpmult);

	frag2 = vec4(normalize(bump * tbnMatrix) * 0.5 + 0.5, 1.0);
	frag3 = vec4(normalize(waves1(0.05) * tbnMatrix) * 0.5 + 0.5, 1.0);


/* DRAWBUFFERS:543 */

	gl_FragData[0] = albedo;
	gl_FragData[1] = vec4(lmcoord.t, mat, lmcoord.s, 1.0);
	gl_FragData[2] = frag2;
}
