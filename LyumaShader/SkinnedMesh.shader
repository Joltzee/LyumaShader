﻿Shader "LyumaShader/SkinnedMesh" 
{
	Properties
	{
        // Shader properties
		_Color ("Main Color", Color) = (1,1,1,1)
		_MainTex ("Base (RGB)", 2D) = "white" {}
        [HDR] _MeshTex ("Mesh Data", 2D) = "white" {}
        //[HDR] _BlendShapeTexArray ("Blend Shape Data", 2DArray) = "black" {}
        //[HDR] _BoneBindTransforms ("Bone Bind Transform Data", 2D) = "black" {}
        //_NumBlendShapes ("Number of blend shapes", Float) = 0
        _BoneCutoff ("Up to 2 bone ranges to render", Vector) = (0,0,0,0)
        _rainbow_coef ("Rainbow bone colors", Float) = 0
    }
	SubShader
	{
    Tags {
            "Queue"="Transparent+10"
            "RenderType"="Opaque" //Transparent"
            "IgnoreProjector"="true"
    }
        // Shader code
		Pass
        {
            Cull Back
            ZTest LEqual
            ZWrite On
            Blend One Zero // SrcAlpha OneMinusSrcAlpha

            CGPROGRAM
            #include "HLSLSupport.cginc"
            #include "UnityCG.cginc"
            #pragma vertex vert
            #pragma geometry geom
            #pragma fragment frag
            #pragma only_renderers d3d9 d3d11 glcore gles 
            #pragma target 4.6
            uniform float4 _Color;
            sampler2D _MainTex;
            Texture2D<half4> _MeshTex;
            //SamplerState sampler_MeshTex;
            uniform float4 _MeshTex_TexelSize;
            //Texture2DArray<half4> _BlendShapeTexArray;
            //uniform float4 _BlendShapeTexArray_TexelSize;
            Texture2D<half4> _BoneBindTexture;
            uniform float4 _BoneBindTexture_TexelSize;
            //uniform float _NumBlendShapes;
            uniform float4 _BoneCutoff;
            uniform float _rainbow_coef;

            struct VertexInput {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float4 tangent : TANGENT;
            };

            struct v2g {
                float4 bindPose_col0 : TEXCOORD3;
                float4 bindPose_col1 : TEXCOORD4;
                float4 bindPose_col2 : TEXCOORD5;
                float4 bindPose_col3 : TEXCOORD6;
            };
            struct g2f {
                float4 pos : SV_POSITION;
                //float4 normal : TEXCOORD1;
                //float4 tangent : TEXCOORD2;
                float4 uv : TEXCOORD3;
            };
            float4x4 CreateMatrixFromCols(float4 c0, float4 c1, float4 c2, float4 c3) {
                return float4x4(c0.x, c1.x, c2.x, c3.x,
                                c0.y, c1.y, c2.y, c3.y,
                                c0.z, c1.z, c2.z, c3.z,
                                c0.w, c1.w, c2.w, c3.w);
            }
            float4x4 CreateMatrixFromVert(v2g v) {
                return CreateMatrixFromCols(v.bindPose_col0, v.bindPose_col1, v.bindPose_col2, v.bindPose_col3);
            }

            v2g vert (VertexInput v) {
                v2g o = (v2g)0;
                float scale = length(v.normal.xyz);
                o.bindPose_col2 = float4(scale * normalize(v.normal.xyz), 0);//scale * float4(1,0,0,0); //float4(scale * normalize(v.normal.xyz), 0);
                o.bindPose_col0 = float4(scale * normalize(v.tangent.xyz), 0);//scale * float4(0,1,0,0); //float4(scale * normalize(v.tangent.xyz), 0);
                o.bindPose_col1 = float4(scale * cross(normalize(v.normal.xyz), normalize(v.tangent.xyz)), 0); // / scale//scale * float4(0,0,1,0); //
                o.bindPose_col3 = float4(v.vertex.xyz, 1);
                return o;
            }

            struct InputBufferElem {
                float4 vertex;
                float4 normal;
                float4 tangent;
                float4 uvColor;
                float4 boneIndices;
                float4 boneWeights;
            };
            #define numInstancePerVert 32

            half4 readHalf4(uint2 pixelIndex) {
                //return _MeshTex.Load(int3(pixelIndex.x, _MeshTex_TexelSize.w - pixelIndex.y - 1, 0));
                return _MeshTex.Load(int3(pixelIndex, 0));
            }

            //half3 readBlendShapeHalf3(uint2 pixelIndex, int blendIdx) {
            //    return _BlendShapeTexArray.Load(int4(pixelIndex, blendIdx, 0)).xyz;
            //}

            int3 genStereoTexCoord(int x, int y) {
            	float2 xyCoord = float2(x, y);
//#if defined(UNITY_SINGLE_PASS_STEREO)
//            	return int3(xyCoord * (3.0 * float2(_BoneBindTexture_TexelSize.zw / _ScreenParams.xy)) + float2(1.,1.), 0);
//#else
            	return int3(xyCoord, 0);
//#endif
            }

            float4x4 readBindTransform(int boneIndex, int yOffset) {
                boneIndex = boneIndex + 1;
                //int adj = sin(_Time.y) < 0.5 ? 1 : -1;//float adj = .5;
                int adj = 0;//float adj = -0.5; // sin(_Time.y) < 0.5 ? 0.5 : -0.5;//1. + lerp(2 * sin(.3*_Time.y), 1., sin(_Time.x) < 0);
                float4x4 ret = 10*CreateMatrixFromCols(
                // bone poses will be written in swizzled format, such that
                // an opaque black texture will give the identity matrix.
                    _BoneBindTexture.Load(int3(genStereoTexCoord(boneIndex-adj, yOffset * 6 + 0))).wxyz,
                    _BoneBindTexture.Load(int3(genStereoTexCoord(boneIndex-adj, yOffset * 6 + 1))).zwxy,
                    _BoneBindTexture.Load(int3(genStereoTexCoord(boneIndex-adj, yOffset * 6 + 2))).yzwx,
                    _BoneBindTexture.Load(int3(genStereoTexCoord(boneIndex-adj, yOffset * 6 + 3))).xyzw
                );
                ret._11_22_33 = 10*_BoneBindTexture.Load(int3(genStereoTexCoord(boneIndex-adj, yOffset * 6 + 5))).xyz;
                ret._44 = 1.0;
                return ret;
            }
            half readBlendShapeState(int blendIndex) {
                float adj = sin(10 * _Time.x);
                return _BoneBindTexture.Load(int3(blendIndex-adj, 4, 0)).x;
            }
            InputBufferElem readMeshData(uint instanceID, uint primitiveID, uint vertexNum) {
                uint pixelNum = 3 * (instanceID + primitiveID * numInstancePerVert) + vertexNum;
                uint2 elemIndex = uint2((pixelNum % 64), pixelNum / 64);
                uint2 pixelIndex = uint2(6 * elemIndex.x, elemIndex.y);
                InputBufferElem o;
                o.vertex = readHalf4(pixelIndex + uint2(0,0));
                o.normal = readHalf4(pixelIndex + uint2(1,0));
                o.tangent = readHalf4(pixelIndex + uint2(2,0));
                o.uvColor = readHalf4(pixelIndex + uint2(3,0));
                o.boneIndices = readHalf4(pixelIndex + uint2(4,0));
                o.boneWeights = readHalf4(pixelIndex + uint2(5,0));
                /*
                for (uint blendIdx = 0; blendIdx < 255 && blendIdx < (uint)_NumBlendShapes; blendIdx++) {
                    half blendValue = readBlendShapeState(blendIdx);
                    pixelIndex = uint2(elemIndex.x, elemIndex.y);// * 3
                    //if (blendValue > 0.0) {
                        o.vertex.xyz += .001 * ((float3)readBlendShapeHalf3(pixelIndex + uint2(0,0), blendIdx)!=0.);
                        //o.normal.xyz += ((float3)readBlendShapeHalf3(pixelIndex + uint2(1,0), blendIdx)!=0.);
                        //o.tangent.xyz += ((float3)readBlendShapeHalf3(pixelIndex + uint2(2,0), blendIdx)!=0.);
                    //}
                }
                //o.uvColor = float4(.1*readHalf4(pixelIndex + uint2(3,0)).w, 0.1*o.normal.w, o.tangent.w, 1);////float4(0.5,.5,.5,.5) + .001*readHalf4(pixelIndex + uint2(3,0)); // float4(instanceID/2. + 0.3, pixelNum / 1000.,0.,1.); //
				*/
                return o;
            }

            [instance(numInstancePerVert)]//3)]
            [maxvertexcount(3)]
            void geom(triangle v2g vertin[3], inout TriangleStream<g2f> tristream,
                    uint primitiveID: SV_PrimitiveID, uint instanceID : SV_GSInstanceID)
            {
                g2f o = (g2f)0;
                uint i;
                [unroll]
                for (i = 0; i < 3; i++) {
                    InputBufferElem buf = readMeshData(instanceID, primitiveID, i);
                    float4x4 boneTransform;
                    float4x4 worldTransform;
                    if (!((buf.boneIndices.x >= _BoneCutoff.x &&
                            (_BoneCutoff.y == 0 || buf.boneIndices.x < _BoneCutoff.y)) ||
                            ((_BoneCutoff.z > 0 && buf.boneIndices.x >= _BoneCutoff.z) &&
                            (_BoneCutoff.w == 0 || buf.boneIndices.x < _BoneCutoff.w)))) {
                        return;
                    }
                    if (dot(buf.boneWeights, buf.boneWeights) > 0.0) {
                        // Should be the likely case.
                        boneTransform = (float4x4)0;
                        float scale = 1.0;
                        boneTransform += buf.boneWeights.x * readBindTransform(buf.boneIndices.x, 0);
                        boneTransform += buf.boneWeights.y * readBindTransform(buf.boneIndices.y, 0);
                        boneTransform += buf.boneWeights.z * readBindTransform(buf.boneIndices.z, 0);
                        boneTransform += buf.boneWeights.w * readBindTransform(buf.boneIndices.w, 0);
						boneTransform = lerp(boneTransform, (float4x4)CreateMatrixFromVert(vertin[2]), all(boneTransform._11_12_13_21 == 0.0) * all(boneTransform._22_23_31_32 == 0.0));
                    } else {
                        boneTransform = float4x4(1,0,0,0, 0,1,0,0, 0,0,1,0, 0,0,0,1);
                    }
                    o.pos = UnityObjectToClipPos(mul(boneTransform, float4(buf.vertex.xyz, 1.)));
                    o.uv = float4(buf.uvColor.xy, buf.boneIndices.x, 0);
                    tristream.Append(o);
                }
            }

            float4 frag(g2f fragin) : SV_Target {
                //return float4(0,0,1,1);
                float4 tex = tex2D(_MainTex, float4(fragin.uv.xy, 0, 1));
                float boneInfluence = fragin.uv.z % 160;
                boneInfluence = (boneInfluence + _Time.y * 10.) % 160;
                tex = lerp(tex, tex * float4(float3(floor(boneInfluence / 20.)/5., frac(boneInfluence / 20.), frac(boneInfluence / 5.) ) * 0.4 + 0.6, 1.), _rainbow_coef);
                //tex += _BoneBindTexture.Sample(sampler_MeshTex, float3(fragin.uv.xy, 0)); //tex2D(_MainTex, fragin.uv);
                clip(tex.a - 0.1);

                return tex * _Color;
                //return float4(fragin.uv.xy, 0, 1) * _Color;
            }
            ENDCG
		}
	} 
}