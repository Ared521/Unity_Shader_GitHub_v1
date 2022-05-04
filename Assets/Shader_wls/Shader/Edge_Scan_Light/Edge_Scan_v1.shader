Shader "Edge_Scan_v1"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _InnerColor ("InnerColor", COLOR) = (1, 1, 1, 1)
        _InnerColorIntensity ("InnerColorIntensity", Range(0, 15)) = 1
        _RimColor ("RimColor", COLOR) = (1, 1, 1, 1)
        _RimColorIntensity ("RimColorIntensity", Range(0, 15)) = 1
        _ScanSpeed ("ScanSpeed", Range(0, 5)) = 1
        _ScanIntensity ("ScanIntensity", Range(1, 5)) = 1
    }
    SubShader
    {
        Tags { "RenderType"="Transparent" }
        LOD 100

        Pass
        {
			ZWrite Off
			Blend SrcAlpha One

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 texcoord : TEXCOORD0;
                float3 normal : NORMAL;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 pos : SV_POSITION;
                float3 normal_World : TEXCOORD1;
                float3 view_World : TEXCOORD2;
                float3 pos_World : TEXCOORD3;
                float2 flow_UV_World_XY : TEXCOORD4;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;

            float4 _InnerColor;
            float _InnerColorIntensity;

            float4 _RimColor;
            float _RimColorIntensity;

            float _ScanSpeed;
            float _ScanIntensity;

            v2f vert (appdata v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.pos_World = mul(unity_ObjectToWorld, v.vertex);
                o.normal_World = normalize(mul(float4(v.normal, 0), unity_WorldToObject).xyz);
                o.view_World = normalize(_WorldSpaceCameraPos.xyz - o.pos_World);
                o.flow_UV_World_XY = o.pos_World - mul(unity_ObjectToWorld, float4(0,0,0,0));
                o.uv = TRANSFORM_TEX(v.texcoord, _MainTex);
                return o;
            }

            half4 frag (v2f i) : SV_Target
            {
                half3 normal_World = normalize(i.normal_World);
                half3 view_World = normalize(i.view_World);
                half fresnel = 1 - max(0, dot(normal_World, view_World));
                half3 finalColor = lerp(_InnerColor.rgb * _InnerColorIntensity, _RimColor.rgb * _RimColorIntensity, fresnel);

                half4 mainTex = tex2D(_MainTex, i.flow_UV_World_XY + _Time.y * _ScanSpeed);
                finalColor = finalColor + mainTex.rgb * _ScanIntensity;
                half finalAlpha = fresnel + mainTex.r;
                return half4(finalColor, finalAlpha);
            }
            ENDCG
        }
    }
}
