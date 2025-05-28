#version 460

layout(location = 0) out vec3 mvVertexPos;
layout(location = 1) out vec3 direction;
layout(location = 2) out vec3 light;
layout(location = 3) out vec2 uv;
layout(location = 4) flat out vec3 normal;
layout(location = 5) flat out int textureIndex;
layout(location = 6) flat out int isBackFace;
layout(location = 7) flat out int ditherSeed;
layout(location = 8) flat out float distanceForLodCheck;
layout(location = 9) flat out int opaqueInLod;

layout(location = 0) uniform vec3 ambientLight;
layout(location = 1) uniform mat4 projectionMatrix;
layout(location = 2) uniform mat4 viewMatrix;
layout(location = 3) uniform ivec3 playerPositionInteger;
layout(location = 4) uniform vec3 playerPositionFraction;

layout(binding = 15) uniform sampler2D torchToneMap;

struct FaceData {
	int encodedPositionAndLightIndex;
	int textureAndQuad;
};
layout(std430, binding = 3) buffer _faceData
{
	FaceData faceData[];
};

struct QuadInfo {
	vec3 normal;
	vec3 corners[4];
	vec2 cornerUV[4];
	uint textureSlot;
	int opaqueInLod;
};

layout(std430, binding = 4) buffer _quads
{
	QuadInfo quads[];
};

layout(std430, binding = 10) buffer _lightData
{
	uint lightData[];
};

struct ChunkData {
	ivec4 position;
	vec4 minPos;
	vec4 maxPos;
	int voxelSize;
	uint lightStart;
	uint vertexStartOpaque;
	uint faceCountsByNormalOpaque[14];
	uint vertexStartTransparent;
	uint vertexCountTransparent;
	uint visibilityState;
	uint oldVisibilityState;
};

layout(std430, binding = 6) buffer _chunks
{
	ChunkData chunks[];
};

void main() {
	int faceID = gl_VertexID >> 2;
	int vertexID = gl_VertexID & 3;
	int chunkID = gl_BaseInstance;
	int voxelSize = chunks[chunkID].voxelSize;
	int encodedPositionAndLightIndex = faceData[faceID].encodedPositionAndLightIndex;
	int textureAndQuad = faceData[faceID].textureAndQuad;
	uint lightIndex = chunks[chunkID].lightStart + 4*(encodedPositionAndLightIndex >> 16);
	uint fullLight = lightData[lightIndex + vertexID];
	vec3 sunLight = vec3(
		fullLight >> 25 & 31u,
		fullLight >> 20 & 31u,
		fullLight >> 15 & 31u
	);
	vec3 blockLight = vec3(
		fullLight >> 10 & 31u,
		fullLight >> 5 & 31u,
		fullLight >> 0 & 31u
	);
    float w = 8;
    float h = 4;
    float flor = w*floor(blockLight.r / w); // [0, w]
    float mod = blockLight.r - flor; // [0, w]
    vec2 torchUV = vec2(
        (blockLight.b + mod*32 + 0.01)/32/w,
        (32*h - blockLight.g - flor/w*32 - 0.01)/32/h
    );
    // vec2 torchUV = vec2(
        // (blockLight.r + mod)/32/w,
        // 0.99//(32*h - blockLight.g - flor)/32/h
    // );
    blockLight = texture(torchToneMap, torchUV).rgb*32;
    // blockLight = texture(torchToneMap, blockLight.xy/32.0).rgb*100;
    // blockLight = texture(torchToneMap, vec3(0.25, 0.8, 0.31)).rgb*100;
    // blockLight.r = texture(torchToneMap, blockLight).r == 0 ? 0 : 100;
	light = max(sunLight*ambientLight, blockLight)/31;
	isBackFace = encodedPositionAndLightIndex>>15 & 1;
	ditherSeed = encodedPositionAndLightIndex & 15;

	textureIndex = textureAndQuad & 65535;
	int quadIndex = textureAndQuad >> 16;

	vec3 position = vec3(
		encodedPositionAndLightIndex & 31,
		encodedPositionAndLightIndex >> 5 & 31,
		encodedPositionAndLightIndex >> 10 & 31
	);

	normal = quads[quadIndex].normal;

	position += quads[quadIndex].corners[vertexID];
	position *= voxelSize;
	position += vec3(chunks[chunkID].position.xyz - playerPositionInteger);
	position -= playerPositionFraction;

	direction = position;

	vec4 mvPos = viewMatrix*vec4(position, 1);
	gl_Position = projectionMatrix*mvPos;
	mvVertexPos = mvPos.xyz;
	distanceForLodCheck = length(mvPos.xyz) + voxelSize;
	uv = quads[quadIndex].cornerUV[vertexID]*voxelSize;
	opaqueInLod = quads[quadIndex].opaqueInLod;
}
