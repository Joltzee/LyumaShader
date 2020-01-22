﻿#ifndef SHADER_SKIN_BASE_CGINC__
#define SHADER_SKIN_BASE_CGINC__
#include "HLSLSupport.cginc"
#include "UnityCG.cginc"

#if defined(UNITY_PASS_FORWARDBASE) || defined(UNITY_PASS_FORWARDADD) || defined(UNITY_PASS_SHADOWCASTER)
#define PRECISE precise
#define TEX2DHALF Texture2D<half4>
#define TEXLOAD(tex, uvcoord) tex.Load(uvcoord)
#else
#define PRECISE
#define TEX2DHALF float4
#define TEXLOAD(tex, uvcoord) half4(1,0,1,1)
#endif

float3 encodeLossyFloat(float inputFloat, inout uint remainder5Bits) {
    PRECISE uint input = asuint(inputFloat);
    if (asuint(_ProjectionParams.x) < 0x1000) {
        input = ((input << 15) | ((input & 0x7ff0000) >> 11));
        //input = ((input & 0xffff0000) >> 16) | ((input & 0xffff) << 16);
    }
    //14+14+4
    //11+11+10
    PRECISE uint newRemainder = (((input & 0x80000000) >> 27) | ((input & 0x1e000) >> 13));
    PRECISE float in1 = (float)(((input & 0x7f000000) >> 19) | ((input & 0x1e0) >> 5));
    PRECISE float in2 = (float)(((input & 0x00fe0000) >> 12) | ((input & 0x700) >> 8));
    PRECISE float in3 = (float)(0x10 | ((remainder5Bits & 0x10) << 7) | ((newRemainder & 0x10) << 6) | ((newRemainder & 0xf) << 6) | (remainder5Bits & 0xf));
    remainder5Bits = newRemainder;
    PRECISE float3 ret = (float3((floor(in1)) / 4096., (floor(in2)) / 4096., (floor(in3)) / 4096.));
    return ret;
}
uint2 decodeLossyFloatShared(float toDecode) {
    PRECISE uint in1 = (uint)(toDecode * 4096.);
    return uint2(((in1&0x400) >>6) | (in1 & 0xf0) >> 4, ((in1&0x800) >>7) | (in1 & 0xf));
}
float decodeLossyFloat(float2 toDecode, uint sharedDecode) {
    PRECISE uint in1 = (uint)(toDecode.x * 4096.);
    PRECISE uint in2 = (uint)(toDecode.y * 4096.);
    PRECISE uint in3 = sharedDecode;
    PRECISE uint outbits = (((in3 & 0x10) << 27) | ((in1 & 0xfe0) << 19) | ((in2 & 0x00fe0) << 12) | ((in3 & 0xf) << 11) | ((in2 & 0xf) << 9) | ((in1 & 0xf) << 5));
    if (asuint(_ProjectionParams.x) < 0x1000) {
        outbits = ((outbits >> 15) | ((outbits & 0xffe0) << 11));
        //outbits = ((outbits & 0xffff0000) >> 16) | ((outbits & 0xffff) << 16);
    }
    return asfloat(outbits);
}

////OLD
float uint14ToFloat(uint input)
{
    PRECISE float output = (f16tof32((input & 0x00003fff)));
    return output;
}
uint floatToUint14(PRECISE float input)
{
    uint output = (f32tof16(input)) & 0x00003fff;
    return output;
}
float3 uintToHalf3(uint input)
{
    PRECISE float3 output = float3(uint14ToFloat(input), uint14ToFloat(input >> 14), uint14ToFloat((input >> 28) & 0x0000000f));
    return output;
}
uint half3ToUint(PRECISE float3 input)
{
    return floatToUint14(input.x) | (floatToUint14(input.y) << 14) | ((floatToUint14(input.z) & 0x0000000f) << 28);
}
////END OLD

/*
float4 matrix_to_quaternion(float3x3 m) {
    // from glm/gtc/quaternion.inl
    // http://www.euclideanspace.com/maths/geometry/rotations/conversions/matrixToQuaternion/
    float4 fourCSquaredMinus1 = float4(
        m._m00 - m._m11 - m._m22,
        m._m11 - m._m00 - m._m22,
        m._m22 - m._m00 - m._m11,
        m._m00 + m._m11 + m._m22);

    if(all(fourCSquaredMinus1.zzz > fourCSquaredMinus1.xyw)) {
        float biggestVal = sqrt(fourCSquaredMinus1.z + 1.) * 0.5;
        float mult = 0.25 / biggestVal;
        return float4((m._m01 - m._m10) * mult, (m._m20 + m._m02) * mult, (m._m12 + m._m21) * mult, biggestVal);
    } else if(all(fourCSquaredMinus1.yyy > fourCSquaredMinus1.xzw)) {
        float biggestVal = sqrt(fourCSquaredMinus1.y + 1.) * 0.5;
        float mult = 0.25 / biggestVal;
        return float4((m._m20 - m._m02) * mult, (m._m01 + m._m10) * mult, biggestVal, (m._m12 + m._m21) * mult);
    } else if(all(fourCSquaredMinus1.xxx > fourCSquaredMinus1.yzw)) {
        float biggestVal = sqrt(fourCSquaredMinus1.x + 1.) * 0.5;
        float mult = 0.25 / biggestVal;
        return float4((m._m12 - m._m21) * mult, biggestVal, (m._m01 + m._m10) * mult, (m._m20 + m._m02) * mult);
    } else {
        float biggestVal = sqrt(fourCSquaredMinus1.w + 1.) * 0.5;
        float mult = 0.25 / biggestVal;
        return float4(biggestVal, (m._m12 - m._m21) * mult, (m._m20 - m._m02) * mult, (m._m01 - m._m10) * mult);
    }
}
*/
float4 matrix_to_quaternion(float3x3 m)
{
    float tr = m._m00 + m._m11 + m._m22;
    float4 q = float4(0, 0, 0, 0);

    if (tr > 0)
    {
        float s = sqrt(tr + 1.0) * 2; // S=4*qw 
        q.w = 0.25 * s;
        q.x = (m._m21 - m._m12) / s;
        q.y = (m._m02 - m._m20) / s;
        q.z = (m._m10 - m._m01) / s;
    }
    else if ((m._m00 > m._m11) && (m._m00 > m._m22))
    {
        float s = sqrt(1.0 + m._m00 - m._m11 - m._m22) * 2; // S=4*qx 
        q.w = (m._m21 - m._m12) / s;
        q.x = 0.25 * s;
        q.y = (m._m01 + m._m10) / s;
        q.z = (m._m02 + m._m20) / s;
    }
    else if (m._m11 > m._m22)
    {
        float s = sqrt(1.0 + m._m11 - m._m00 - m._m22) * 2; // S=4*qy
        q.w = (m._m02 - m._m20) / s;
        q.x = (m._m01 + m._m10) / s;
        q.y = 0.25 * s;
        q.z = (m._m12 + m._m21) / s;
    }
    else
    {
        float s = sqrt(1.0 + m._m22 - m._m00 - m._m11) * 2; // S=4*qz
        q.w = (m._m10 - m._m01) / s;
        q.x = (m._m02 + m._m20) / s;
        q.y = (m._m12 + m._m21) / s;
        q.z = 0.25 * s;
    }

    return q;
}

float3x3 quaternion_to_matrix(float4 quat)
{
    // https://gist.github.com/mattatz/86fff4b32d198d0928d0fa4ff32cf6fa
    float x = quat.x, y = quat.y, z = quat.z, w = quat.w;
    float x2 = x + x, y2 = y + y, z2 = z + z;
    float xx = x * x2, xy = x * y2, xz = x * z2;
    float yy = y * y2, yz = y * z2, zz = z * z2;
    float wx = w * x2, wy = w * y2, wz = w * z2;

    return float3x3(1.0 - (yy + zz), xy - wz, xz + wy,
        xy + wz, 1.0 - (xx + zz), yz - wx,
        xz - wy, yz + wx, 1.0 - (xx + yy));
}


float4x4 CreateMatrixFromCols(float4 c0, float4 c1, float4 c2, float4 c3) {
    return float4x4(c0.x, c1.x, c2.x, c3.x,
                    c0.y, c1.y, c2.y, c3.y,
                    c0.z, c1.z, c2.z, c3.z,
                    c0.w, c1.w, c2.w, c3.w);
}
float4x4 CreateMatrixFromRows(float4 r0, float4 r1, float4 r2, float4 r3) {
    return float4x4(r0, r1, r2, r3);
}
int3 genLoadTexCoord(int x, int y) {
    return int3(x, y, 0);
}

///////////////////////////////////////////////////

struct boneblend_VertexInput {
    float4 vertex : POSITION;
    float3 normal : NORMAL;
    float4 tangent : TANGENT;
    half4 color : COLOR; // name in ASCII
    float4 texcoord : TEXCOORD0;
};
struct boneblend_v2f {
    float4 texcoord : TEXCOORD0;
	float4 quat01 : TEXCOORD1;
	float3 vertex : TEXCOORD2;
	float4 pos : SV_POSITION;
};

uniform float4 _BoneBindTexture_TexelSize;
TEX2DHALF _BoneBindTexture;
TEX2DHALF _MeshTex;

float2 pixelToUV(float2 pixelCoordinate, float2 offset) {
    //return (floor(pixelCoordinate) + offset) / _ScreenParams.xy;
    float2 correctedTexelSize = _BoneBindTexture_TexelSize.zw;
    if (correctedTexelSize.x / _ScreenParams.x > 1.9) {
        correctedTexelSize.x *= 0.5;
    }
    return (floor(pixelCoordinate) + offset) / correctedTexelSize;
    //return float2(ret.x, 1.0 - ret.y);
}

boneblend_v2f newbonedump_vert(boneblend_VertexInput v) {
    boneblend_v2f o = (boneblend_v2f)0;
    o.vertex = v.vertex.xyz;
    o.texcoord = v.texcoord;
    float2 baseUV = float2(0,0);
    float2 dims = float2(0,0);
    float boneId = v.texcoord.w;
    float xheight = 3;
    if (v.texcoord.z >= 1. && v.texcoord.w >= 1.) {
        // blend shape
        o.quat01 = v.vertex.xxxx;
        o.texcoord.xy += float2(0, 16);
        baseUV = float2(v.texcoord.w, 0);
        dims = float2(1,1);
    } else {
        float3x3 mat = float3x3(1,0,0,0,1,0,0,0,1);
        if (v.texcoord.z >= 1. && v.texcoord.w < 1.) {
            // root position
            mat = unity_ObjectToWorld;
            baseUV = float2(0, 1);
            dims = float2(1,xheight);
            o.vertex = mul(unity_ObjectToWorld, float4(0,0,0,1)).xyz;
        } else if (v.texcoord.z < 1. && v.texcoord.w >= 1.) {
            // bone position
            float3 zaxis = normalize(v.normal);
            float3 xaxis = normalize(v.tangent.xyz);
            float3 yaxis = normalize(cross(zaxis, xaxis));
            mat = float3x3(xaxis, yaxis, zaxis);
            baseUV = float2(v.texcoord.w, 1);
            dims = float2(1,xheight);
        }
        o.quat01 = 0.5 + 0.5 * matrix_to_quaternion(mat);
    }
    o.texcoord.xy *= dims;
#if UNITY_UV_STARTS_AT_TOP
    float2 uvflip = float2(1., -1.);
#else
    float2 uvflip = float2(1., 1.);
#endif
    o.pos = float4(uvflip*(pixelToUV(baseUV, v.texcoord.xy * dims) * 2. - float2(1.,1.)), 0., 1.);
    return o;
}

float4 newbonedump_frag(boneblend_v2f i) : SV_Target {
	uint idx = (uint)floor(i.texcoord.y);
    uint yRemainder5Bits = 0;
    float2 encodedFloatY = encodeLossyFloat(i.vertex.y, yRemainder5Bits).xy;
    float3 encodedFloatXybits = encodeLossyFloat(i.vertex.x, yRemainder5Bits);
    yRemainder5Bits = 0;
    float3 encodedFloatZ = encodeLossyFloat(i.vertex.z, yRemainder5Bits);
	float4 ret = .0.xxxx;
	switch (idx) {
	case 0:
        ret = i.quat01;
		break;
	case 1:
        ret = float4(encodedFloatXybits.xy, encodedFloatY.x, encodedFloatXybits.z);
		break;
	case 2:
        ret = float4(encodedFloatZ.xy, encodedFloatY.y, encodedFloatZ.z);
		break;
    case 3:
        ret.xyz = uintToHalf3(asuint(i.vertex.x));
		break;
    case 4:
        ret.xyz = uintToHalf3(asuint(i.vertex.y));
		break;
    case 5:
        ret.xyz = uintToHalf3(asuint(i.vertex.z));
		break;
	}
    return ret;
}

float3x3 rotationMatrix(float3 axis, float angle)
{
    float s = sin(angle);
    float c = cos(angle);
    float oc = 1.0 - c;
    
    return float3x3(oc * axis.x * axis.x + c,           oc * axis.x * axis.y - axis.z * s,  oc * axis.z * axis.x + axis.y * s,
                oc * axis.x * axis.y + axis.z * s,  oc * axis.y * axis.y + c,           oc * axis.y * axis.z - axis.x * s,
                oc * axis.z * axis.x - axis.y * s,  oc * axis.y * axis.z + axis.x * s,  oc * axis.z * axis.z + c);
}

float3 positionFromBoneData(float4 posxyRead, float4 posyzRead) {
    uint2 sharedXY = decodeLossyFloatShared(posxyRead.a);
    uint2 sharedZ = decodeLossyFloatShared(posyzRead.a);
    return float3(
        decodeLossyFloat(posxyRead.rg, sharedXY.x),
        decodeLossyFloat(float2(posxyRead.b, posyzRead.b), sharedXY.y),
        decodeLossyFloat(posyzRead.rg, sharedZ.x));
}

void readBoneQP(int boneIndex, int yOffset, out float4 quatOut, out float3 posOut) {
    boneIndex = boneIndex + 1;
    quatOut = (TEXLOAD(_BoneBindTexture, int3(genLoadTexCoord(boneIndex, yOffset * 5 + 1))) - 0.5) * 2;

    float4 posxyRead = TEXLOAD(_BoneBindTexture, int3(genLoadTexCoord(boneIndex, yOffset * 5 + 2)));
    float4 posyzRead = TEXLOAD(_BoneBindTexture, int3(genLoadTexCoord(boneIndex, yOffset * 5 + 3)));
    posOut = float3(
        asfloat(half3ToUint(TEXLOAD(_BoneBindTexture, int3(genLoadTexCoord(boneIndex, yOffset * 5 + 4))))),
        asfloat(half3ToUint(TEXLOAD(_BoneBindTexture, int3(genLoadTexCoord(boneIndex, yOffset * 5 + 5))))),
        asfloat(half3ToUint(TEXLOAD(_BoneBindTexture, int3(genLoadTexCoord(boneIndex, yOffset * 5 + 6))))));
    posOut = positionFromBoneData(posxyRead, posyzRead);
}
float4x4 boneQPToTransform(float4 quat, float3 pos) {
    float4 position = float4(pos, 1.0);

    float3x3 mat = quaternion_to_matrix(quat);
    //if (all(boneName == float4('H', 'a', 't', 0))) {
    //    mat = float3x3(0,0,0,0,0,0,0,0,0);
    return CreateMatrixFromCols(float4(mat._11_12_13, 0), float4(mat._21_22_23, 0), float4(mat._31_32_33, 0), position);
}

half4x4 readBoneMapMatrix(int boneIndex, int yOffset) {
    //return float4x4(1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1);
    float4 lastColumn = TEXLOAD(_MeshTex, int3(boneIndex, yOffset + 3, 0));
    if (dot(lastColumn, lastColumn) <= 1.0) {
        return float4x4(1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1);
    }
    return CreateMatrixFromCols(
        TEXLOAD(_MeshTex, int3(boneIndex, yOffset + 0, 0)),
        TEXLOAD(_MeshTex, int3(boneIndex, yOffset + 1, 0)),
        TEXLOAD(_MeshTex, int3(boneIndex, yOffset + 2, 0)),
        lastColumn);
}

///////////////////////////x/////////////////////


void vertModifier(inout appdata_full v) {
    float4x4 boneTransform;
    uint4 boneIndices = (uint4)floor(v.texcoord2);
    float4 boneWeights = (float4)(v.texcoord3 + float4(1.e-10, 0, 0, 0));
    boneWeights /= dot(boneWeights, 1..xxxx);
    //if (abs(dot(1..xxxx, v.uv4) - 1.0) < 0.1) {
        boneTransform = (float4x4)0;
        float scale = 1.0;
        uint yoffset = 0;
        float3 pos;
        float4 quat;
        //boneIndices = uint4(boneIndexMap(boneIndices.x),boneIndexMap(boneIndices.y),boneIndexMap(boneIndices.z),boneIndexMap(boneIndices.w));
        readBoneQP(boneIndices.x, yoffset, quat, pos);
        boneTransform += boneWeights.x * mul(boneQPToTransform(quat, pos), readBoneMapMatrix(boneIndices.x, yoffset));
        readBoneQP(boneIndices.y, yoffset, quat, pos);
        boneTransform += boneWeights.y * mul(boneQPToTransform(quat, pos), readBoneMapMatrix(boneIndices.y, yoffset));
        readBoneQP(boneIndices.z, yoffset, quat, pos);
        boneTransform += boneWeights.z * mul(boneQPToTransform(quat, pos), readBoneMapMatrix(boneIndices.z, yoffset));
        readBoneQP(boneIndices.w, yoffset, quat, pos);
        boneTransform += boneWeights.w * mul(boneQPToTransform(quat, pos), readBoneMapMatrix(boneIndices.w, yoffset));
    //} else {
    //    boneTransform = float4x4(1,0,0,0, 0,1,0,0, 0,0,1,0, 0,0,0,1);
    //}
    v.vertex = mul(boneTransform, float4(v.vertex.xyz, 1.));
    v.normal = mul((float3x3)boneTransform, v.normal.xyz);
    v.tangent = float4(mul((float3x3)boneTransform, v.tangent.xyz), v.tangent.w);
}
#endif