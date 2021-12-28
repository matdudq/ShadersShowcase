Shader "Custom/DiffuseSpecular"
{
    Properties
    {
        _AlbedoTex ("Albedo", 2D) = "white" {}      
        _Smoothness ("_Smoothness", Range(0,1)) = 0.5
    }

    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100
    
        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"           
        
        CBUFFER_START(UnityPerMaterial)
            float4 _AlbedoTex_ST;
        
            float4 _Tint;
            float4 _SpecularTint;
            
            float _Smoothness;
        CBUFFER_END
        
        TEXTURE2D(_AlbedoTex);
        SAMPLER(sampler_AlbedoTex);
        
        struct VertexData {
            float4 position : POSITION;
            float2 uv : TEXCOORD0;
            float3 normal: NORMAL;
        };
            
        struct Interpolators {
            float4 position : SV_POSITION;
            float2 uv : TEXCOORD0;
            float3 normal: NORMAL;
            float3 worldPos: TEXCOORD1;
        };
        
        ENDHLSL
        
        Pass
        {
            HLSLPROGRAM
                       
            #pragma vertex VertexProgram
            #pragma fragment FragmentProgram
            
            Interpolators VertexProgram(VertexData vertexData)
            {
                Interpolators interpolators;
                interpolators.position = TransformObjectToHClip(vertexData.position);
                interpolators.worldPos = mul(unity_ObjectToWorld, vertexData.position);
                interpolators.uv = TRANSFORM_TEX(vertexData.uv, _AlbedoTex);
                interpolators.normal = TransformObjectToWorldNormal(vertexData.normal); // normalize(mul(transpose((float3x3)unity_WorldToObject),vertexData.normal))
                return interpolators;
            }
            
            float4 FragmentProgram(Interpolators interpolators) : SV_TARGET
            {                
                float3 normal = normalize(interpolators.normal);
                float3 lightDir = _MainLightPosition;
                float3 lightColor = _MainLightColor;  
                
                float3 viewDir = normalize(_WorldSpaceCameraPos.xyz - interpolators.worldPos);
                
                float3 diffuse = lightColor * saturate(dot(lightDir, normal));
                
                float3 halfVector = normalize(lightDir + viewDir);
                float specularExponent = exp2(_Smoothness * 11 + 2);
                
                float3 specular = pow( saturate(dot(halfVector, normal)), specularExponent) * _Smoothness * lightColor;

                float3 albedoTexture = SAMPLE_TEXTURE2D(_AlbedoTex, sampler_AlbedoTex, interpolators.uv) ;       
                
                float3 color = diffuse * albedoTexture + specular;
                
                return float4(color,1);
            }
            
            ENDHLSL
        }
    }
}
