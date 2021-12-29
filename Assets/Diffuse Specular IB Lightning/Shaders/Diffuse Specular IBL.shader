Shader "Custom/Diffuse Specular IBL"
{
    Properties
    {
        _AlbedoTex ("Albedo", 2D) = "white" {}
        
        _Smoothness ("_Smoothness", Range(0,1)) = 0.5

        [NoScaleOffset] 
        _DiffuseHDR ("Diffuse HDR", 2D) = "white" {}
        _DiffuseIBLIntensity ("Diffuse IBL Intensity", Range(0,1)) = 0.5
        
        [NoScaleOffset] 
        _SpecularHDR ("Specular HDR", 2D) = "white" {}
        _SpecularIBLIntensity ("Specular IBL Intensity", Range(0,1)) = 0.5
                
        [NoScaleOffset] 
        _NormalMap ("Normal map",2D) = "bump"{}
        _NormalMapIntensity ("Normal map intensity", Range(0,1)) = 0.5
        
        [NoScaleOffset] 
        _DisplacementMap ("Displacement map",2D) = "bump"{}
        _DisplacementRange ("Displacement range", Range(0,1)) = 0.5
        
        _FresnelIntensity ("Fresnel Intensity", float) = 0.5
    }

    SubShader
    {
        Tags { "LightMode" = "UniversalForward"}
                          
        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
                
        CBUFFER_START(UnityPerMaterial)
        
            float4 _AlbedoTex_ST;
            float4 _DiffuseHDR_ST;
            float4 _SpecularHDR_ST;

            float _Smoothness;      
              
            float _DiffuseIBLIntensity;        
            float _SpecularIBLIntensity;        
            float _DisplacementRange;
            float _NormalMapIntensity;
            
            float _FresnelIntensity;
            
        CBUFFER_END
        
        TEXTURE2D(_AlbedoTex);
        SAMPLER(sampler_AlbedoTex);
        
        TEXTURE2D(_DiffuseHDR);
        SAMPLER(sampler_DiffuseHDR);
        
        TEXTURE2D(_SpecularHDR);
        SAMPLER(sampler_SpecularHDR);
        
        TEXTURE2D(_NormalMap);
        SAMPLER(sampler_NormalMap);
        
        TEXTURE2D(_DisplacementMap);
        SAMPLER(sampler_DisplacementMap);

        struct VertexData {
            float4 position : POSITION;
            float2 uv : TEXCOORD0;
            float3 normal: NORMAL;
            float4 tangent: TANGENT;
        };
            
        struct Interpolators {
            float4 position : SV_POSITION;
            float2 uv : TEXCOORD0;
            float3 normalWS: TEXCOORD1;
            float3 tangentWS: TEXCOORD2;
            float3 bitangentWS: TEXCOORD3;
            float3 worldPos: TEXCOORD4;
        };
        
        ENDHLSL
        
        Pass
        {    
            HLSLPROGRAM
                       
            #pragma vertex VertexProgram
            #pragma fragment FragmentProgram
                  
            #define TAU 6.28318530718
                        
            Interpolators VertexProgram(VertexData vertexData)
            {
                Interpolators interpolators;
                
                interpolators.uv = TRANSFORM_TEX(vertexData.uv, _AlbedoTex).xy;
                
                float displacement = SAMPLE_TEXTURE2D_LOD(_DisplacementMap, sampler_DisplacementMap, interpolators.uv,0).r;
                vertexData.position.xyz += vertexData.normal * displacement * _DisplacementRange;
                interpolators.position = TransformObjectToHClip(vertexData.position.xyz);
                
                interpolators.worldPos = mul(unity_ObjectToWorld, vertexData.position).xyz;
                
                VertexNormalInputs normalInputs = GetVertexNormalInputs(vertexData.normal, vertexData.tangent);
                interpolators.normalWS = normalInputs.normalWS;
                interpolators.tangentWS = normalInputs.tangentWS;
                interpolators.bitangentWS = normalInputs.bitangentWS;
                
                return interpolators;
            }
            
            float2 DirToRectilinear(float3 direction)
            {
                return float2( atan2(direction.z,direction.x) / TAU + 0.5 , direction.y * 0.5 + 0.5);
            }
                        
            float4 FragmentProgram(Interpolators interpolators) : SV_TARGET
            {              
                float3 tangentSpaceNormal = UnpackNormal(SAMPLE_TEXTURE2D(_NormalMap,sampler_NormalMap, interpolators.uv));
                tangentSpaceNormal = lerp(float3(0,0,1), tangentSpaceNormal, _NormalMapIntensity);
                float3x3 tangentToWorldSpaceMat = {
                     interpolators.tangentWS.x, interpolators.bitangentWS.x, interpolators.normalWS.x,
                     interpolators.tangentWS.y, interpolators.bitangentWS.y, interpolators.normalWS.y,
                     interpolators.tangentWS.z, interpolators.bitangentWS.z, interpolators.normalWS.z
                     };
                
                float3 normal = normalize(mul(tangentToWorldSpaceMat, tangentSpaceNormal));

                Light light = GetMainLight();
                float3 lightDir = normalize(light.direction);
                float3 lightColor = light.color;  
                
                float3 viewDir = normalize(_WorldSpaceCameraPos.xyz - interpolators.worldPos);
                
                //Diffuse
                float lambert = saturate(dot(normal, lightDir));
                float3 diffuse = lightColor * lambert;
                
                //IBL Diffuse
                float3 diffuseIBL = SAMPLE_TEXTURE2D_LOD(_DiffuseHDR, sampler_DiffuseHDR, DirToRectilinear(normal),0).xyz;
                diffuse += diffuseIBL * _DiffuseIBLIntensity;
                
                //Specular
                float3 halfVector = normalize(lightDir + viewDir);
                float specularExponent = exp2(_Smoothness * 11) + 2;
                float3 specular = step(0, lambert) * saturate(dot(halfVector, normal)) ;
                specular = pow( specular, specularExponent) * _Smoothness ;

                //IBL Specular
                float frsnel = pow(1-saturate(dot(viewDir,interpolators.normalWS)),_FresnelIntensity);
                float3 viewReflected = reflect(viewDir,normal);
                float mip = (1-_Smoothness)*6;
                float3 specularIBL = SAMPLE_TEXTURE2D_LOD(_SpecularHDR, sampler_SpecularHDR, DirToRectilinear(viewReflected),mip).xyz;
                specular += specularIBL * _SpecularIBLIntensity * frsnel;

                float3 albedoTexture = SAMPLE_TEXTURE2D(_AlbedoTex, sampler_AlbedoTex, interpolators.uv).xyz;       
                
                float3 color = diffuse * albedoTexture + specular;
                
                return float4(color,1);
            }
            
            ENDHLSL
        }
    }
}
