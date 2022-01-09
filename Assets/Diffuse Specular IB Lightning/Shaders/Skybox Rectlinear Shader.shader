Shader "Custom/Skybox/Rectlinear"
{
    Properties
    {
        _MainTex ("Skybox texture", 2D) = "white" {}
    }
    SubShader
    {
        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"           
        
        CBUFFER_START(UnityPerMaterial)
            half4 _MainTex_ST;
        CBUFFER_END
        
        TEXTURE2D(_MainTex);
        SAMPLER(sampler_MainTex);
        
        struct appdata
        {
            half4 vertex : POSITION;
            half3 uv : TEXCOORD0;
        };

        struct v2f
        {
            half3 uv : TEXCOORD0;
            half4 vertex : SV_POSITION;
        };
        
        ENDHLSL

        Pass
        {
            Cull Back
                   
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #define TAU 6.28318530718
            
            half2 DirToRectilinear(half3 direction)
            {
                return half2( atan2(direction.z,direction.x) / TAU + 0.5 , direction.y * 0.5 + 0.5);
            }

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = TransformObjectToHClip(v.vertex.xyz);
                o.uv = v.uv;
                return o;
            }

            half4 frag (v2f i) : SV_Target
            {   
                half3 color = SAMPLE_TEXTURE2D_LOD(_MainTex, sampler_MainTex, DirToRectilinear(i.uv),0 ).rgb;    
                return half4(color,1);
            }
                   
            ENDHLSL
        }
    }
}
