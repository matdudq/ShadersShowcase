Shader "Custom/Fresnel Mask"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _FresnelMaskColor ("Fresnel Mask Color", Color) = (.25, .5, .5, 1)
        _FresnelIntensity ("Fresnel Intensity", Range(0,10)) = 1
    }
    SubShader
    {        
        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"           
        
        CBUFFER_START(UnityPerMaterial)
            half4 _MainTex_ST;
            half _FresnelIntensity;
            half4 _FresnelMaskColor;
        CBUFFER_END
        
        TEXTURE2D(_MainTex);
        SAMPLER(sampler_MainTex);
        
        struct appdata
        {
            half4 vertex : POSITION;
            half3 normal : normal;
            half2 uv : TEXCOORD0;
        };

        struct v2f
        {
            half2 uv : TEXCOORD0;
            half4 vertex : SV_POSITION;
            half4 worldPosition : TEXCOORD1;
            half3 normal : normal;
        };
        
        ENDHLSL
        
        Pass
        {
            HLSLPROGRAM
                       
           #pragma vertex vert
            #pragma fragment frag

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = TransformObjectToHClip(v.vertex.xyz);
                o.worldPosition = mul(unity_ObjectToWorld,v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.normal = TransformObjectToWorldNormal(v.normal);
                return o;
            }

            half4 frag (v2f i) : SV_Target
            {
                half3 viewDir = normalize(_WorldSpaceCameraPos.xyz - i.worldPosition.xyz);
                half fresnelMask = pow(saturate(dot(viewDir,i.normal)), _FresnelIntensity);
                half4 col = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv) * fresnelMask + (1 - fresnelMask) * _FresnelMaskColor;
                return col;
            }
            
            ENDHLSL
        }
    }
}
