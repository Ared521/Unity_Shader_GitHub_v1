Shader "402Shader"
{
    Properties
    {
        _Albedo_Texture ("Albedo_Texture", 2D) = "white" {}
        _Normal_Map ("NormalMap", 2D) = "bump" {}
        _IBL_Map ("IBL_Map", CUBE) = "white" {}
        _RoughnessAndMetalTexture ("RoughnessAndMetalTexture", 2D) = "white" {}
        _RoughnessAdjust ("RoughnessAdjust", Float) = 0
        _MetalAdjust ("MetalAdjust", Float) = 0
        _NormalMapIntensity ("NormalMapIntensity", Float) = 1
        _SH_DiffuseIntensity ("SH_DiffuseIntensity", Float) = 1 
        _DiffuseIntensity ("DiffuseIntensity", Float) = 1
        _Shininess ("Shininess", Float) = 1
        _LightIntensity ("LightIntensity", Float) = 1
        _IBL_Expose ("IBL_Expose", Float) = 1


        [HideInInspector]custom_SHAr("Custom SHAr", Vector) = (0, 0, 0, 0)
		[HideInInspector]custom_SHAg("Custom SHAg", Vector) = (0, 0, 0, 0)
		[HideInInspector]custom_SHAb("Custom SHAb", Vector) = (0, 0, 0, 0)
		[HideInInspector]custom_SHBr("Custom SHBr", Vector) = (0, 0, 0, 0)
		[HideInInspector]custom_SHBg("Custom SHBg", Vector) = (0, 0, 0, 0)
		[HideInInspector]custom_SHBb("Custom SHBb", Vector) = (0, 0, 0, 0)
		[HideInInspector]custom_SHC("Custom SHC", Vector) = (0, 0, 0, 1)
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            Tags{"LightMode" = "ForwardBase"}
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag	
			#pragma multi_compile_fwdbase
			#include "UnityCG.cginc"
			#include "AutoLight.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 texcoord : TEXCOORD0;
                float3 normal : NORMAL;
                float4 tangent : TANGENT;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 pos : SV_POSITION;
                float3 world_Normal : TEXCOORD1;
                float3 world_Tangent : TEXCOORD2;
                float3 world_Binormal : TEXCOORD3;
                float3 world_Pos : TEXCOORD4;
                LIGHTING_COORDS(6, 7)
            };

            sampler2D _Albedo_Texture;
            sampler2D _Normal_Map;
            sampler2D _RoughnessAndMetalTexture;
            samplerCUBE _IBL_Map;
            float4 _IBL_Map_HDR;
            float4 _Albedo_Texture_ST;
            float _NormalMapIntensity;
            float _RoughnessAdjust;
            float _MetalAdjust;
            float _SH_DiffuseIntensity;
            float _DiffuseIntensity;
            float4 _LightColor0;
            float _LightIntensity;
            float _Shininess;
            float _IBL_Expose;

            half4 custom_SHAr;
			half4 custom_SHAg;
			half4 custom_SHAb;
			half4 custom_SHBr;
			half4 custom_SHBg;
			half4 custom_SHBb;
			half4 custom_SHC;

            float3 ACESFilm(float3 x)
			{
				float a = 2.51f;
				float b = 0.03f;
				float c = 2.43f;
				float d = 0.59f;
				float e = 0.14f;
				return saturate((x*(a*x + b)) / (x*(c*x + d) + e));
			};

            float3 Custom_SH(float3 normal_Dir)
            {
                float4 normalForSH = float4(normal_Dir, 1.0);
				//SHEvalLinearL0L1
				half3 x;
				x.r = dot(custom_SHAr, normalForSH);
				x.g = dot(custom_SHAg, normalForSH);
				x.b = dot(custom_SHAb, normalForSH);

				//SHEvalLinearL2
				half3 x1, x2;
				// 4 of the quadratic (L2) polynomials
				half4 vB = normalForSH.xyzz * normalForSH.yzzx;
				x1.r = dot(custom_SHBr, vB);
				x1.g = dot(custom_SHBg, vB);
				x1.b = dot(custom_SHBb, vB);

				// Final (5th) quadratic (L2) polynomial
				half vC = normalForSH.x*normalForSH.x - normalForSH.y*normalForSH.y;
				x2 = custom_SHC.rgb * vC;

				float3 sh = max(float3(0.0, 0.0, 0.0), (x + x1 + x2));
				sh = pow(sh, 1.0 / 2.2);
                return sh;
            }

            v2f vert (appdata v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                float3 world_Pos = mul(unity_ObjectToWorld, v.vertex);
                o.world_Pos = world_Pos;
                o.world_Normal = normalize(mul(float4(v.normal, 0), unity_WorldToObject).xyz);
                o.world_Tangent = normalize(mul(unity_ObjectToWorld, float4(v.tangent.xyz, 0)).xyz);
                o.world_Binormal = normalize(cross(o.world_Normal, o.world_Tangent)) * v.tangent.w;
                o.uv = TRANSFORM_TEX(v.texcoord, _Albedo_Texture);

                TRANSFER_VERTEX_TO_FRAGMENT(o)

                return o;
            }

            half4 frag (v2f i) : SV_Target
            {
                //Texture Info
                half4 albedo_Gramma = tex2D(_Albedo_Texture, i.uv);
                //第一步，输入的纹理如果是sRGB（Gamma0.45），那我们要进行一个操作转换到线性空间。这个操作叫做Remove Gamma Correction，在数学上是一个2.2的幂运算。所有的输入，计算，输出，都能统一在线性空间中，那么结果是最真实的，玩家会说这个游戏画质很强很真实。事实上因为计算这一步已经是在线性空间描述的了，所以只要保证输入输出是在线性空间就行了。
                half4 albedo_Color = pow(albedo_Gramma, 2.2);
                half4 roughnessAndMetal_Map = tex2D(_RoughnessAndMetalTexture, i.uv);
                //half roughness = roughnessAndMetal_Map.r;
                half roughness = saturate(roughnessAndMetal_Map.r + _RoughnessAdjust);
                half metal = saturate(roughnessAndMetal_Map.g + _MetalAdjust);
                half3 baseMaterial_Color = albedo_Color.rgb * (1 - metal);
                //half3 metalMaterial_Color = abledo_Color.rgb * metal;
                half3 metalMaterial_Color = lerp(0, albedo_Color.rgb, metal);
                half4 normal_Map = tex2D(_Normal_Map, i.uv);
                half3 normal_Map_Data = UnpackNormal(normal_Map);

                //Dir
                half3 normal_Dir = normalize(i.world_Normal);
                half3 view_Dir = normalize(_WorldSpaceCameraPos.xyz - i.world_Pos);
                half3 tangent_Dir = normalize(i.world_Tangent);
                half3 binormal_Dir = normalize(i.world_Binormal);
                normal_Dir = normalize(tangent_Dir * normal_Map_Data.x * _NormalMapIntensity + binormal_Dir * normal_Map_Data.y * _NormalMapIntensity + normal_Dir);

                //Lighting Info
                half3 directLight_Dir = normalize(_WorldSpaceLightPos0.xyz);
                half shadow = LIGHT_ATTENUATION(i);

                //Direct Diffuse 
                half NdotL = max(0, dot(normal_Dir, directLight_Dir));
                half directDiffuse_Term = saturate(max(0, pow(NdotL, 
                1 / _DiffuseIntensity)));
                //防止有些漫反射地方过暗
                half half_Lambert = (directDiffuse_Term + 1) * 0.5;
                half3 directDiffuse_Color = directDiffuse_Term * _LightColor0.rgb * baseMaterial_Color.rgb * shadow;

                //Direct Specular 
                half3 half_LightAndView_Dir = normalize(_WorldSpaceLightPos0.xyz + view_Dir);
                half NdotH = max(0, dot(normal_Dir, half_LightAndView_Dir));
                //这里跟光滑度有关
                half smoothness = 1 - roughness;
                half shininessLerp = lerp(1, _Shininess, smoothness);
                half specular_Term = saturate(pow(NdotH, _Shininess * shininessLerp));
                half3 specular_Color = specular_Term * metalMaterial_Color * _LightColor0.xyz * _LightIntensity * shadow;

                //Indirect Specular (IBL) IBL跟光照无关了，所以是view_Dir有关，跟light_Dir无关。
                half3 reflect_Dir = reflect(-view_Dir, normal_Dir);
                roughness = roughness * (1.7 - 0.7 * roughness);
                half mipMap_Level = roughness * 6;
                half4 IBL_Map = texCUBElod(_IBL_Map, float4(reflect_Dir, mipMap_Level));
                half3 IBL_Color_HDR = DecodeHDR(IBL_Map, _IBL_Map_HDR);
                half3 IBL_Color = IBL_Color_HDR * metalMaterial_Color * _IBL_Expose * half_Lambert;

                //Indirect Diffuse
                float3 SH_Diffuse = Custom_SH(normal_Dir) * baseMaterial_Color.rgb * _SH_DiffuseIntensity * half_Lambert;

                half3 final_Color = specular_Color + directDiffuse_Color + IBL_Color + SH_Diffuse;
                half3 tone_Color = ACESFilm(final_Color);
                tone_Color = pow(tone_Color, 1.0 / 2.2);
                return float4(tone_Color, 1);
            }
            ENDCG
        }
    }
    Fallback "Diffuse"
}
