Shader "Custom/DiffuseSpecular"
{
    Properties
    {
        _AlbedoTex ("Albedo", 2D) = "white" {}      
        _Smoothness ("_Smoothness", Range(0,1)) = 0.5
    }

    SubShader
    {
        Tags { "RenderPipeline"="UniversalPipeline" "RenderType"="Opaque" }
        LOD 100
    
        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"           
        
        CBUFFER_START(UnityPerMaterial)
            half4 _AlbedoTex_ST;
        
            half4 _Tint;
            half4 _SpecularTint;
            
            half _Smoothness;
        CBUFFER_END
        
        TEXTURE2D(_AlbedoTex);
        SAMPLER(sampler_AlbedoTex);
        
        struct VertexData {
            half4 position : POSITION;
            half2 uv : TEXCOORD0;
            half3 normal: NORMAL;
        };
            
        struct Interpolators {
            half4 position : SV_POSITION;
            half2 uv : TEXCOORD0;
            half3 normal: NORMAL;
            half3 worldPos: TEXCOORD1;
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
                interpolators.position = TransformObjectToHClip(vertexData.position.xyz);
                interpolators.worldPos = mul(unity_ObjectToWorld, vertexData.position).xyz;
                interpolators.uv = TRANSFORM_TEX(vertexData.uv, _AlbedoTex).xy;
                interpolators.normal = TransformObjectToWorldNormal(vertexData.normal).xyz; // normalize(mul(transpose((half3x3)unity_WorldToObject),vertexData.normal))
                return interpolators;
            }
            
            half4 FragmentProgram(Interpolators interpolators) : SV_TARGET
            {                
                half3 normal = normalize(interpolators.normal);
                half3 lightDir = _MainLightPosition.xyz;
                half3 lightColor = _MainLightColor.xyz;  
                
                half3 viewDir = normalize(_WorldSpaceCameraPos.xyz - interpolators.worldPos);
                
                half3 diffuse = lightColor * saturate(dot(lightDir, normal));
                
                half3 halfVector = normalize(lightDir + viewDir);
                half specularExponent = exp2(_Smoothness * 11 + 2);
                
                half3 specular = pow( saturate(dot(halfVector, normal)), specularExponent) * _Smoothness * lightColor;

                half3 albedoTexture = SAMPLE_TEXTURE2D(_AlbedoTex, sampler_AlbedoTex, interpolators.uv).xyz;       
                
                half3 color = diffuse * albedoTexture + specular;
                
                return half4(color,1);
            }
            
            ENDHLSL
        }
    }
}
