﻿Shader "LyumaShader/SkinnedMeshMorphInstanced" 
{
    Properties
    {
        // Waifu2d Properties:
        _2d_coef ("Twodimensionalness", Range(0, 1)) = 0.99
        _facing_coef ("Face in Profile", Range (-1, 1)) = 0.0
        _lock2daxis_coef ("Lock 2d Axis", Range (0, 1)) = 1.0
        _local3d_coef ("See self in 3d", Range (0, 1)) = 1.0
        _zcorrect_coef ("Squash Z (good=.975; 0=3d; 1=z-fight)", Float) = 0.975
        _ztweak_coef ("Tweak z clip", Range (-1, 1)) = 0.0
        [Enum(Always,0,VROnly,1)] _DisplayVROnly ("Support non-VR", Int) = 0
        [Enum(Off,0,FaceMirror,1)] _FaceMirrors ("Face Mirror/Camera?", Int) = 0

        // Shader properties
        _Color ("Main Color", Color) = (1,1,1,1)
        _MainTex ("Base (RGB)", 2D) = "white" {}
        _MorphTex ("Base Morphed (RGB)", 2D) = "white" {}
        _MorphTex1 ("Base Morphed (RGB)", 2D) = "white" {}
        _MorphTex2 ("Base Morphed (RGB)", 2D) = "white" {}
        _MorphTex3 ("Base Morphed (RGB)", 2D) = "white" {}
        _MorphTex4 ("Base Morphed (RGB)", 2D) = "white" {}
        [HDR] _MeshTex ("Mesh Data", 2D) = "white" {}
        [HDR] _MeshTex1 ("Mesh Data", 2D) = "white" {}
        [HDR] _MeshTex2 ("Mesh Data", 2D) = "white" {}
        [HDR] _MeshTex3 ("Mesh Data", 2D) = "white" {}
        [HDR] _MeshTex4 ("Mesh Data", 2D) = "white" {}
        //[HDR] _BlendShapeTexArray ("Blend Shape Data", 2DArray) = "black" {}
        [HDR] _BoneBindTransforms ("Bone Bind Transform Data", 2D) = "black" {}
        //_NumBlendShapes ("Number of blend shapes", Float) = 0
        _BoneCutoff ("Up to 2 bone ranges to render", Vector) = (0,0,0,0)
        _rainbow_coef ("Rainbow bone colors", Float) = 0
        _MorphValue ("Current morph offset", Range(0, 10)) = 0
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
            Cull Front
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
            #define _BoneBindTransforms _BoneBindTexture
            #define _BoneBindTransforms_TexelSize _BoneBindTexture_TexelSize
            uniform float4 _Color;
            uniform float _MorphValue;
            sampler2D _MorphTex;
            sampler2D _MorphTex1;
            sampler2D _MorphTex2;
            sampler2D _MorphTex3;
            sampler2D _MorphTex4;
            Texture2D<half4> _MeshTex;
            Texture2D<half4> _MeshTex1;
            Texture2D<half4> _MeshTex2;
            Texture2D<half4> _MeshTex3;
            Texture2D<half4> _MeshTex4;
            //Texture2DArray<half4> _BlendShapeTexArray;
            //uniform float4 _BlendShapeTexArray_TexelSize;
            Texture2D<half4> _BoneBindTransforms;
            //uniform float _NumBlendShapes;
            uniform float4 _BoneCutoff;
            uniform float _rainbow_coef;

            struct VertexInput {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float4 tangent : TANGENT;
                fixed4 color : COLOR0;
                float4 uv : TEXCOORD0;
            };

            struct v2g {
                float4 centerRot : TEXCOORD0;
                float4 bindPose_col0 : TEXCOORD1;
                float4 bindPose_col1 : TEXCOORD2;
                float4 bindPose_col2 : TEXCOORD3;
                float4 bindPose_col3 : TEXCOORD4;
                float morphValue : TEXCOORD5;
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
                o.centerRot = v.uv;
                if (v.color.r > 0.5 && v.color.g > 0.5) {
                    o.morphValue = 4.;
                } else if (v.color.r > 0.5) {
                    o.morphValue = 0.;
                } else if (v.color.g > 0.5) {
                    o.morphValue = 1.;
                } else {
                    o.morphValue = 2.;
                }
                //o.morphValue = lerp(4., lerp(2., lerp(0., 1., v.color.r > 0.5), v.color.r + v.color.b < 0.5), v.color.g + v.color.b < 0.5);
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

            #define readHalf4(tex, pixelIndex) (tex).Load(int3((pixelIndex), 0))
            /*half4 readHalf4(uint2 pixelIndex) {
                //return _MeshTex.Load(int3(pixelIndex.x, _MeshTex_TexelSize.w - pixelIndex.y - 1, 0));
                return _MeshTex.Load(int3(pixelIndex, 0));
            }*/

            #define READ_MESH_DATA(tex1, tex2) \
                    o.vertex = lerp(readHalf4(tex1, pixelIndex + uint2(0,0)), readHalf4(tex2, pixelIndex + uint2(0,0)), texFrac); \
                    o.normal = lerp(readHalf4(tex1, pixelIndex + uint2(1,0)), readHalf4(tex2, pixelIndex + uint2(1,0)), texFrac); \
                    o.tangent = lerp(readHalf4(tex1, pixelIndex + uint2(2,0)), readHalf4(tex2, pixelIndex + uint2(2,0)), texFrac); \
                    o.uvColor = lerp(readHalf4(tex1, pixelIndex + uint2(3,0)), readHalf4(tex2, pixelIndex + uint2(3,0)), texFrac); \
                    o.boneIndices = lerp(readHalf4(tex1, pixelIndex + uint2(4,0)), readHalf4(tex2, pixelIndex + uint2(4,0)), floor(2*texFrac)); \
                    o.boneWeights = lerp(readHalf4(tex1, pixelIndex + uint2(5,0)), readHalf4(tex2, pixelIndex + uint2(5,0)), floor(2*texFrac))

            //half3 readBlendShapeHalf3(uint2 pixelIndex, int blendIdx) {
            //    return _BlendShapeTexArray.Load(int4(pixelIndex, blendIdx, 0)).xyz;
            //}

            int3 genStereoTexCoord(int x, int y) {
                float2 xyCoord = float2(x, y);
//#if defined(UNITY_SINGLE_PASS_STEREO)
//              return int3(xyCoord * (3.0 * float2(_BoneBindTransforms_TexelSize.zw / _ScreenParams.xy)) + float2(1.,1.), 0);
//#else
                return int3(xyCoord, 0);
//#endif
            }

            /*half4x4 readBoneMapMatrix(int boneIndex, int yOffset) {
                half4x4 ret = CreateMatrixFromCols(
                    readHalf4(int2(boneIndex, yOffset + 0)),
                    readHalf4(int2(boneIndex, yOffset + 1)),
                    readHalf4(int2(boneIndex, yOffset + 2)),
                    readHalf4(int2(boneIndex, yOffset + 3))
                );
                return ret;
            }*/

            float4x4 readBindTransform(int boneIndex, int yOffset) {
                boneIndex = boneIndex + 1;
                //int adj = sin(_Time.y) < 0.5 ? 1 : -1;//float adj = .5;
                int adj = 0;//float adj = -0.5; // sin(_Time.y) < 0.5 ? 0.5 : -0.5;//1. + lerp(2 * sin(.3*_Time.y), 1., sin(_Time.x) < 0);
                float4x4 ret = 10*CreateMatrixFromCols(
                // bone poses will be written in swizzled format, such that
                // an opaque black texture will give the identity matrix.
                    _BoneBindTransforms.Load(int3(genStereoTexCoord(boneIndex-adj, yOffset * 6 + 0))).wxyz,
                    _BoneBindTransforms.Load(int3(genStereoTexCoord(boneIndex-adj, yOffset * 6 + 1))).zwxy,
                    _BoneBindTransforms.Load(int3(genStereoTexCoord(boneIndex-adj, yOffset * 6 + 2))).yzwx,
                    _BoneBindTransforms.Load(int3(genStereoTexCoord(boneIndex-adj, yOffset * 6 + 3))).xyzw
                );
                ret._11_22_33 = 10*_BoneBindTransforms.Load(int3(genStereoTexCoord(boneIndex-adj, yOffset * 6 + 5))).xyz;
                ret._44 = 1.0;
                return ret; //readBoneMapMatrix(boneIndex, 0)));
            }
            half readBlendShapeState(int blendIndex) {
                float adj = sin(10 * _Time.x);
                return _BoneBindTransforms.Load(int3(blendIndex-adj, 4, 0)).x;
            }
            InputBufferElem readMeshData(uint instanceID, uint primitiveID, uint vertexNum, float morphValue) {
                uint pixelNum = 3 * (instanceID + primitiveID * numInstancePerVert) + vertexNum;
                uint2 elemIndex = uint2((pixelNum % 64), pixelNum / 64);
                uint2 pixelIndex = uint2(6 * elemIndex.x, elemIndex.y + 8);

                InputBufferElem o;
                float whichTex = floor(morphValue % 5);
                float texFrac = frac(morphValue);
                if (whichTex < 1) {
                    READ_MESH_DATA(_MeshTex, _MeshTex1);
                } else if (whichTex < 2) {
                    READ_MESH_DATA(_MeshTex1, _MeshTex2);
                } else if (whichTex < 3) {
                    READ_MESH_DATA(_MeshTex2, _MeshTex3);
                } else if (whichTex < 4) {
                    READ_MESH_DATA(_MeshTex3, _MeshTex4);
                } else {
                    READ_MESH_DATA(_MeshTex4, _MeshTex);
                }
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
                    InputBufferElem buf = readMeshData(instanceID, primitiveID % 625, i, vertin[0].morphValue);
                    float4x4 rootBone = readBindTransform(-1, 0);
                    float4x4 boneTransform;
                    float s, c;
                    float angle = atan2(rootBone._31, rootBone._11);
                    sincos(vertin[0].centerRot.w + UNITY_PI/2. + angle, s, c);
                    float3 center = vertin[0].centerRot.xyz;
                    /*float4x4 worldTransform = mul(unity_WorldToObject, float4x4(
                                     1, 0, 0, 0,
                                     0, 1, 0, 0,
                                     0, 0, 1, 0,
                                     0, 0, 0, 1));*/
                    /*float4x4 worldTransform = float4x4(c, 0, s, -center.x,
                                     0, 1, 0, center.y,
                                     -s, 0, c, center.z,
                                     0, 0, 0, 1);*/
                                     /*
                    float4x4 worldTransform = mul(unity_WorldToObject, float4x4(
                                     -c, 0, s, 0,
                                     0, -1, 0, 0,
                                     s, 0, c, 0,
                                     0, 0, 0, 1));
                    worldTransform._14_34_24_44 = float4(center.xz, 0., 1.);*/
                    /*float4x4 worldTransform = mul(unity_WorldToObject, float4x4(
                                     -c, 0, s, -center.x,
                                     0, -1, 0, 0,
                                     s, 0, c, -center.z,
                                     0, 0, 0, 0));
                    worldTransform._44 = 1.;*/
                    /*float4x4 worldTransform = mul(unity_WorldToObject, float4x4(
                                     -c, 0, s, 0,
                                     0, -1, 0, 0,
                                     s, 0, c, 0,
                                     0, 0, 0, 0));
                    worldTransform._14_34_24_44 = float4(center.xz, -center.y, 1.);*/
                    /*float4x4 worldTransform = float4x4(-c, 0, s, -center.x,
                                     0, -1, 0, center.y,
                                     s, 0, c, center.z,
                                     0, 0, 0, 1);*/
                    /*GOOD:float4x4 worldTransform = float4x4(c, 0, s, center.x,
                                     0, 1, 0, 0.,
                                     -s, 0, c, center.z,
                                     0, 0, 0, 1);*/
                    /*float2x2 worldRot1 = mul(float2x2(unity_WorldToObject._11_13_31_33), float2x2(
                                     c, s, -s, c));
                    float4x4 worldTransform = float4x4(worldRot1._11, 0, worldRot1._21, center.x,
                                     0, 1, 0, 0., 
                                     worldRot1._12, 0, worldRot1._22, center.z,
                                     0, 0, 0, 1);*/
                    //worldTransform._14_34_24_44 = float4(center.xz, -center.y, 1.);

                    /* test */
                    /*
                    float4x4 worldTransform = mul(unity_WorldToObject, float4x4(1, 0, 0, center.x,
                                     0, -1, 0, 0, 
                                     0, 0, -1, center.z,
                                     0, 0, 0, 1));
                    //worldTransform._14_34_24_44 = float4(center.xz, 0., 1.);
                    worldTransform._24_44 = float2(0., 1.);
                    //worldTransform._14_34 = float2(center.x, center.z);
                    worldTransform._11_13_31_33 = float4(c, s, -s, c);
                    worldTransform._12_21_23_32 = float4(0,0,0,0);
                    worldTransform._22 = 1.;
                    */
                    /*
                    float4x4 worldTransform = float4x4(1, 0, 0, center.x,
                                     0, -1, 0, 1., 
                                     0, 0, -1, center.z,
                                     0, 0, 0, 1);
                    worldTransform._11_13_31_33 = float4(c, s, -s, c);*/
                    float4x4 worldTransform = float4x4(1, 0, 0, center.x,
                                     0, -1, 0, rootBone._24, //center.y+
                                     0, 0, -1, center.z,
                                     0, 0, 0, 1);
                    worldTransform._11_13_31_33 = float4(c, s, -s, c);
                    //o.uv = float4(buf.uvColor.xy, buf.boneIndices.x, vertin[0].morphValue);
                    //tristream.Append(o);
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
                        //boneTransform = lerp(boneTransform, (float4x4)CreateMatrixFromVert(vertin[2]), all(boneTransform._11_12_13_21 == 0.0) * all(boneTransform._22_23_31_32 == 0.0));
                    } else {
                        boneTransform = float4x4(1,0,0,0, 0,1,0,0, 0,0,1,0, 0,0,0,1);
                    }
                    /*o.pos = mul(unity_ObjectToWorld, mul(worldTransform, mul(boneTransform, float4(buf.vertex.xyz, 1.))));
                    o.pos = mul(unity_WorldToObject, o.pos + float4(mul(unity_ObjectToWorld, float4(0, 0, -1, 1)).xz, 0., 1.).xzyw);
                    o.pos = UnityObjectToClipPos(o.pos);*/
                    //o.pos = mul(unity_ObjectToWorld, mul(worldTransform, mul(boneTransform, float4(buf.vertex.xyz, 1.))));
                    o.pos = UnityObjectToClipPos(mul(worldTransform, mul(boneTransform, float4(buf.vertex.xyz, 1.))));
                    o.uv = float4(buf.uvColor.xy, buf.boneIndices.x, vertin[0].morphValue);
                    tristream.Append(o);
                }
            }

            float4 frag(g2f fragin) : SV_Target {
                //return float4(0,0,1,1);
                float4 tex;
                float whichTex = floor(fragin.uv.w % 5);
                float texFrac = frac(fragin.uv.w);
                if (whichTex < 1) {
                    tex = lerp(
                        tex2D(_MorphTex, float4(fragin.uv.xy, 0, 1)),
                        tex2D(_MorphTex1, float4(fragin.uv.xy, 0, 1)),
                        texFrac);
                } else if (whichTex < 2) {
                    tex = lerp(
                        tex2D(_MorphTex1, float4(fragin.uv.xy, 0, 1)),
                        tex2D(_MorphTex2, float4(fragin.uv.xy, 0, 1)),
                        texFrac);
                } else if (whichTex < 3) {
                    tex = lerp(
                        tex2D(_MorphTex2, float4(fragin.uv.xy, 0, 1)),
                        tex2D(_MorphTex3, float4(fragin.uv.xy, 0, 1)),
                        texFrac);
                } else if (whichTex < 4) {
                    tex = lerp(
                        tex2D(_MorphTex3, float4(fragin.uv.xy, 0, 1)),
                        tex2D(_MorphTex4, float4(fragin.uv.xy, 0, 1)),
                        texFrac);
                } else {
                    tex = lerp(
                        tex2D(_MorphTex4, float4(fragin.uv.xy, 0, 1)),
                        tex2D(_MorphTex, float4(fragin.uv.xy, 0, 1)),
                        texFrac);
                }
                float boneInfluence = fragin.uv.z % 160;
                boneInfluence = (boneInfluence + _Time.y * 10.) % 160;
                tex = lerp(tex, tex * float4(float3(floor(boneInfluence / 20.)/5., frac(boneInfluence / 20.), frac(boneInfluence / 5.) ) * 0.4 + 0.6, 1.), _rainbow_coef);
                //tex += _BoneBindTransforms.Sample(sampler_MeshTex, float3(fragin.uv.xy, 0)); //tex2D(_MainTex, fragin.uv);
                clip(tex.a - 0.1);

                return tex * _Color;
                //return float4(fragin.uv.xy, 0, 1) * _Color;
            }
            ENDCG
        }
    } 
    Fallback "Unlit/Texture"
    Fallback "Diffuse"
}
