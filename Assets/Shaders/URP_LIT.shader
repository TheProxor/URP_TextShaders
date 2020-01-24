﻿Shader "TheProxor/URP_Lit"
{
	Properties
	{
		// Specular vs Metallic workflow
		[HideInInspector] _WorkflowMode("WorkflowMode", Float) = 1.0

		[HideInInspector][MainColor] _BaseColor("Color", Color) = (0.5,0.5,0.5,1)
		[HideInInspector][MainTexture] _BaseMap("Albedo", 2D) = "white" {}

		[HideInInspector]_Cutoff("Alpha Cutoff", Range(0.0, 1.0)) = 0.5

		[HideInInspector]_Smoothness("Smoothness", Range(0.0, 1.0)) = 0.5
		[HideInInspector]_GlossMapScale("Smoothness Scale", Range(0.0, 1.0)) = 1.0
		[HideInInspector]_SmoothnessTextureChannel("Smoothness texture channel", Float) = 0

		[HideInInspector][Gamma] _Metallic("Metallic", Range(0.0, 1.0)) = 0.0
		[HideInInspector]_MetallicGlossMap("Metallic", 2D) = "white" {}

		[HideInInspector]_SpecColor("Specular", Color) = (0.2, 0.2, 0.2)
		[HideInInspector]_SpecGlossMap("Specular", 2D) = "white" {}

		[HideInInspector][ToggleOff] _SpecularHighlights("Specular Highlights", Float) = 1.0
		[HideInInspector][ToggleOff] _EnvironmentReflections("Environment Reflections", Float) = 1.0

		[HideInInspector]_BumpScale("Scale", Float) = 1.0
		[HideInInspector]_BumpMap("Normal Map", 2D) = "bump" {}

		[HideInInspector]_OcclusionStrength("Strength", Range(0.0, 1.0)) = 1.0
		[HideInInspector]_OcclusionMap("Occlusion", 2D) = "white" {}

		[HideInInspector]_EmissionColor("Color", Color) = (0,0,0)
		[HideInInspector]_EmissionMap("Emission", 2D) = "white" {}

		// Blending state
		[HideInInspector] _Surface("__surface", Float) = 0.0
		[HideInInspector] _Blend("__blend", Float) = 0.0
		[HideInInspector] _AlphaClip("__clip", Float) = 0.0
		[HideInInspector] _SrcBlend("__src", Float) = 1.0
		[HideInInspector] _DstBlend("__dst", Float) = 0.0
		[HideInInspector] _ZWrite("__zw", Float) = 1.0
		[HideInInspector] _Cull("__cull", Float) = 2.0

		_ReceiveShadows("Receive Shadows", Float) = 1.0
		// Editmode props
		[HideInInspector] _QueueOffset("Queue offset", Float) = 0.0

		// ObsoleteProperties
		[HideInInspector] _MainTex("BaseMap", 2D) = "white" {}
		[HideInInspector] _Color("Base Color", Color) = (0.5, 0.5, 0.5, 1)
		[HideInInspector] _GlossMapScale("Smoothness", Float) = 0.0
		[HideInInspector] _Glossiness("Smoothness", Float) = 0.0
		[HideInInspector] _GlossyReflections("EnvironmentReflections", Float) = 0.0
	}

	SubShader
	{
		// Universal Pipeline tag is required. If Universal render pipeline is not set in the graphics settings
		// this Subshader will fail. One can add a subshader below or fallback to Standard built-in to make this
		// material work with both Universal Render Pipeline and Builtin Unity Pipeline
		Tags{"RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" "IgnoreProjector" = "True"}
		LOD 300
		// ------------------------------------------------------------------
		//  Forward pass. Shades all light in a single pass. GI + emission + Fog
		Pass
		{
				// Lightmode matches the ShaderPassName set in UniversalRenderPipeline.cs. SRPDefaultUnlit and passes with
				// no LightMode tag are also rendered by Universal Render Pipeline
				Name "ForwardLit"
				Tags{"LightMode" = "UniversalForward"}

				Blend[_SrcBlend][_DstBlend]
				ZWrite[_ZWrite]
				Cull[_Cull]

				HLSLPROGRAM
				// Required to compile gles 2.0 with standard SRP library
				// All shaders must be compiled with HLSLcc and currently only gles is not using HLSLcc by default
				#pragma prefer_hlslcc gles
				#pragma exclude_renderers d3d11_9x
				#pragma target 2.0

				// -------------------------------------
				// Material Keywords
				#pragma shader_feature _NORMALMAP
				#pragma shader_feature _ALPHATEST_ON
				#pragma shader_feature _ALPHAPREMULTIPLY_ON
				#pragma shader_feature _EMISSION
				#pragma shader_feature _METALLICSPECGLOSSMAP
				#pragma shader_feature _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
				#pragma shader_feature _OCCLUSIONMAP

				#pragma shader_feature _SPECULARHIGHLIGHTS_OFF
				#pragma shader_feature _ENVIRONMENTREFLECTIONS_OFF
				#pragma shader_feature _SPECULAR_SETUP
				#pragma shader_feature _RECEIVE_SHADOWS_OFF

				// -------------------------------------
				// Universal Pipeline keywords
				#pragma multi_compile _ _MAIN_LIGHT_SHADOWS
				#pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
				#pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
				#pragma multi_compile _ _ADDITIONAL_LIGHT_SHADOWS
				#pragma multi_compile _ _SHADOWS_SOFT
				#pragma multi_compile _ _MIXED_LIGHTING_SUBTRACTIVE

				// -------------------------------------
				// Unity defined keywords
				#pragma multi_compile _ DIRLIGHTMAP_COMBINED
				#pragma multi_compile _ LIGHTMAP_ON
				#pragma multi_compile_fog

				//--------------------------------------
				// GPU Instancing
				#pragma multi_compile_instancing

				#pragma vertex LitPassVertex
				#pragma fragment LitPassFragment

				#ifndef UNIVERSAL_LIT_INPUT_INCLUDED
				#define UNIVERSAL_LIT_INPUT_INCLUDED

				#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
				#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/CommonMaterial.hlsl"
				#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/SurfaceInput.hlsl"

				CBUFFER_START(UnityPerMaterial)
					float4 _BaseMap_ST;
					half4 _BaseColor;
					half4 _SpecColor;
					half4 _EmissionColor;
					half _Cutoff;
					half _Smoothness;
					half _Metallic;
					half _BumpScale;
					half _OcclusionStrength;
				CBUFFER_END

				TEXTURE2D(_OcclusionMap);       SAMPLER(sampler_OcclusionMap);
				TEXTURE2D(_MetallicGlossMap);   SAMPLER(sampler_MetallicGlossMap);
				TEXTURE2D(_SpecGlossMap);       SAMPLER(sampler_SpecGlossMap);

				#ifdef _SPECULAR_SETUP
					#define SAMPLE_METALLICSPECULAR(uv) SAMPLE_TEXTURE2D(_SpecGlossMap, sampler_SpecGlossMap, uv)
				#else
					#define SAMPLE_METALLICSPECULAR(uv) SAMPLE_TEXTURE2D(_MetallicGlossMap, sampler_MetallicGlossMap, uv)
				#endif

				half4 SampleMetallicSpecGloss(float2 uv, half albedoAlpha)
				{
					half4 specGloss;

					#ifdef _METALLICSPECGLOSSMAP
						specGloss = SAMPLE_METALLICSPECULAR(uv);
						#ifdef _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
							specGloss.a = albedoAlpha * _Smoothness;
						#else
							specGloss.a *= _Smoothness;
						#endif
					#else // _METALLICSPECGLOSSMAP
						#if _SPECULAR_SETUP
							specGloss.rgb = _SpecColor.rgb;
						#else
							specGloss.rgb = _Metallic.rrr;
						#endif

						#ifdef _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
							specGloss.a = albedoAlpha * _Smoothness;
						#else
							specGloss.a = _Smoothness;
						#endif
					#endif

					return specGloss;
				}

				half SampleOcclusion(float2 uv)
				{
					#ifdef _OCCLUSIONMAP
					// TODO: Controls things like these by exposing SHADER_QUALITY levels (low, medium, high)
					#if defined(SHADER_API_GLES)
					return SAMPLE_TEXTURE2D(_OcclusionMap, sampler_OcclusionMap, uv).g;
					#else
					half occ = SAMPLE_TEXTURE2D(_OcclusionMap, sampler_OcclusionMap, uv).g;
					return LerpWhiteTo(occ, _OcclusionStrength);
					#endif
					#else
					return 1.0;
					#endif
				}

				inline void InitializeStandardLitSurfaceData(float2 uv, out SurfaceData outSurfaceData)
				{
					half4 albedoAlpha = SampleAlbedoAlpha(uv, TEXTURE2D_ARGS(_BaseMap, sampler_BaseMap));
					outSurfaceData.alpha = Alpha(albedoAlpha.a, _BaseColor, _Cutoff);

					half4 specGloss = SampleMetallicSpecGloss(uv, albedoAlpha.a);
					outSurfaceData.albedo = albedoAlpha.rgb * _BaseColor.rgb;

					#if _SPECULAR_SETUP
						outSurfaceData.metallic = 1.0h;
						outSurfaceData.specular = specGloss.rgb;
					#else
						outSurfaceData.metallic = specGloss.r;
						outSurfaceData.specular = half3(0.0h, 0.0h, 0.0h);
					#endif

					outSurfaceData.smoothness = specGloss.a;
					outSurfaceData.normalTS = SampleNormal(uv, TEXTURE2D_ARGS(_BumpMap, sampler_BumpMap), _BumpScale);
					outSurfaceData.occlusion = SampleOcclusion(uv);
					outSurfaceData.emission = SampleEmission(uv, _EmissionColor.rgb, TEXTURE2D_ARGS(_EmissionMap, sampler_EmissionMap));
				}

				#endif // UNIVERSAL_INPUT_SURFACE_PBR_INCLUDED


				#ifndef UNIVERSAL_FORWARD_LIT_PASS_INCLUDED
				#define UNIVERSAL_FORWARD_LIT_PASS_INCLUDED

				#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

				struct Attributes
				{
					float4 positionOS   : POSITION;
					float3 normalOS     : NORMAL;
					float4 tangentOS    : TANGENT;
					float2 texcoord     : TEXCOORD0;
					float2 lightmapUV   : TEXCOORD1;
					UNITY_VERTEX_INPUT_INSTANCE_ID
				};

				struct Varyings
				{
					float2 uv                       : TEXCOORD0;
					DECLARE_LIGHTMAP_OR_SH(lightmapUV, vertexSH, 1);

					#ifdef _ADDITIONAL_LIGHTS
					float3 positionWS               : TEXCOORD2;
					#endif

					#ifdef _NORMALMAP
					float4 normalWS                 : TEXCOORD3;    // xyz: normal, w: viewDir.x
					float4 tangentWS                : TEXCOORD4;    // xyz: tangent, w: viewDir.y
					float4 bitangentWS              : TEXCOORD5;    // xyz: bitangent, w: viewDir.z
					#else
					float3 normalWS                 : TEXCOORD3;
					float3 viewDirWS                : TEXCOORD4;
					#endif

					half4 fogFactorAndVertexLight   : TEXCOORD6; // x: fogFactor, yzw: vertex light

					#ifdef _MAIN_LIGHT_SHADOWS
					float4 shadowCoord              : TEXCOORD7;
					#endif

					float4 positionCS               : SV_POSITION;
					UNITY_VERTEX_INPUT_INSTANCE_ID
					UNITY_VERTEX_OUTPUT_STEREO
				};

				void InitializeInputData(Varyings input, half3 normalTS, out InputData inputData)
				{
					inputData = (InputData)0;

					#ifdef _ADDITIONAL_LIGHTS
					inputData.positionWS = input.positionWS;
					#endif

					#ifdef _NORMALMAP
					half3 viewDirWS = half3(input.normalWS.w, input.tangentWS.w, input.bitangentWS.w);
					inputData.normalWS = TransformTangentToWorld(normalTS,
						half3x3(input.tangentWS.xyz, input.bitangentWS.xyz, input.normalWS.xyz));
					#else
					half3 viewDirWS = input.viewDirWS;
					inputData.normalWS = input.normalWS;
					#endif

					inputData.normalWS = NormalizeNormalPerPixel(inputData.normalWS);
					viewDirWS = SafeNormalize(viewDirWS);

					inputData.viewDirectionWS = viewDirWS;
					#if defined(_MAIN_LIGHT_SHADOWS) && !defined(_RECEIVE_SHADOWS_OFF)
					inputData.shadowCoord = input.shadowCoord;
					#else
					inputData.shadowCoord = float4(0, 0, 0, 0);
					#endif
					inputData.fogCoord = input.fogFactorAndVertexLight.x;
					inputData.vertexLighting = input.fogFactorAndVertexLight.yzw;
					inputData.bakedGI = SAMPLE_GI(input.lightmapUV, input.vertexSH, inputData.normalWS);
				}

				///////////////////////////////////////////////////////////////////////////////
				//                  Vertex and Fragment functions                            //
				///////////////////////////////////////////////////////////////////////////////

				// Used in Standard (Physically Based) shader
				Varyings LitPassVertex(Attributes input)
				{
					Varyings output = (Varyings)0;

					UNITY_SETUP_INSTANCE_ID(input);
					UNITY_TRANSFER_INSTANCE_ID(input, output);
					UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

					VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
					VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS, input.tangentOS);
					half3 viewDirWS = GetCameraPositionWS() - vertexInput.positionWS;
					half3 vertexLight = VertexLighting(vertexInput.positionWS, normalInput.normalWS);
					half fogFactor = ComputeFogFactor(vertexInput.positionCS.z);

					output.uv = TRANSFORM_TEX(input.texcoord, _BaseMap);

					#ifdef _NORMALMAP
					output.normalWS = half4(normalInput.normalWS, viewDirWS.x);
					output.tangentWS = half4(normalInput.tangentWS, viewDirWS.y);
					output.bitangentWS = half4(normalInput.bitangentWS, viewDirWS.z);
					#else
					output.normalWS = NormalizeNormalPerVertex(normalInput.normalWS);
					output.viewDirWS = viewDirWS;
					#endif

					OUTPUT_LIGHTMAP_UV(input.lightmapUV, unity_LightmapST, output.lightmapUV);
					OUTPUT_SH(output.normalWS.xyz, output.vertexSH);

					output.fogFactorAndVertexLight = half4(fogFactor, vertexLight);

					#ifdef _ADDITIONAL_LIGHTS
					output.positionWS = vertexInput.positionWS;
					#endif

					#if defined(_MAIN_LIGHT_SHADOWS) && !defined(_RECEIVE_SHADOWS_OFF)
					output.shadowCoord = GetShadowCoord(vertexInput);
					#endif

					output.positionCS = vertexInput.positionCS;

					return output;
				}

				// Used in Standard (Physically Based) shader
				half4 LitPassFragment(Varyings input) : SV_Target
				{
					UNITY_SETUP_INSTANCE_ID(input);
					UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

					SurfaceData surfaceData;
					InitializeStandardLitSurfaceData(input.uv, surfaceData);

					InputData inputData;
					InitializeInputData(input, surfaceData.normalTS, inputData);

					half4 color = UniversalFragmentPBR(inputData, surfaceData.albedo, surfaceData.metallic, surfaceData.specular, surfaceData.smoothness, surfaceData.occlusion, surfaceData.emission, surfaceData.alpha);

					color.rgb = MixFog(color.rgb, inputData.fogCoord);
					return color;
				}
				#endif		
				ENDHLSL
		}

		Pass
		{
				Name "ShadowCaster"
				Tags{"LightMode" = "ShadowCaster"}

				ZWrite On
				ZTest LEqual
				Cull[_Cull]

				HLSLPROGRAM
				// Required to compile gles 2.0 with standard srp library
				#pragma prefer_hlslcc gles
				#pragma exclude_renderers d3d11_9x
				#pragma target 2.0

				// -------------------------------------
				// Material Keywords
				#pragma shader_feature _ALPHATEST_ON

				//--------------------------------------
				// GPU Instancing
				#pragma multi_compile_instancing
				#pragma shader_feature _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A

				#pragma vertex ShadowPassVertex
				#pragma fragment ShadowPassFragment

				#include "Assets/Common/LitInput.hlsl"
				
				#ifndef UNIVERSAL_SHADOW_CASTER_PASS_INCLUDED
				#define UNIVERSAL_SHADOW_CASTER_PASS_INCLUDED

				#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
				#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"

				float3 _LightDirection;

				struct Attributes
				{
					float4 positionOS   : POSITION;
					float3 normalOS     : NORMAL;
					float2 texcoord     : TEXCOORD0;
					UNITY_VERTEX_INPUT_INSTANCE_ID
				};

				struct Varyings
				{
					float2 uv           : TEXCOORD0;
					float4 positionCS   : SV_POSITION;
				};

				float4 GetShadowPositionHClip(Attributes input)
				{
					float3 positionWS = TransformObjectToWorld(input.positionOS.xyz);
					float3 normalWS = TransformObjectToWorldNormal(input.normalOS);

					float4 positionCS = TransformWorldToHClip(ApplyShadowBias(positionWS, normalWS, _LightDirection));

					#if UNITY_REVERSED_Z
					positionCS.z = min(positionCS.z, positionCS.w * UNITY_NEAR_CLIP_VALUE);
					#else
					positionCS.z = max(positionCS.z, positionCS.w * UNITY_NEAR_CLIP_VALUE);
					#endif

					return positionCS;
				}

				Varyings ShadowPassVertex(Attributes input)
				{
					Varyings output;
					UNITY_SETUP_INSTANCE_ID(input);

					output.uv = TRANSFORM_TEX(input.texcoord, _BaseMap);
					output.positionCS = GetShadowPositionHClip(input);
					return output;
				}

				half4 ShadowPassFragment(Varyings input) : SV_TARGET
				{
					Alpha(SampleAlbedoAlpha(input.uv, TEXTURE2D_ARGS(_BaseMap, sampler_BaseMap)).a, _BaseColor, _Cutoff);
					return 0;
				}
				#endif
				ENDHLSL
		}

		Pass
		{
				Name "DepthOnly"
				Tags{"LightMode" = "DepthOnly"}

				ZWrite On
				ColorMask 0
				Cull[_Cull]

				HLSLPROGRAM
				// Required to compile gles 2.0 with standard srp library
				#pragma prefer_hlslcc gles
				#pragma exclude_renderers d3d11_9x
				#pragma target 2.0

				#pragma vertex DepthOnlyVertex
				#pragma fragment DepthOnlyFragment

				// -------------------------------------
				// Material Keywords
				#pragma shader_feature _ALPHATEST_ON
				#pragma shader_feature _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A

				//--------------------------------------
				// GPU Instancing
				#pragma multi_compile_instancing

				#include "Assets/Common/LitInput.hlsl"

				#ifndef UNIVERSAL_DEPTH_ONLY_PASS_INCLUDED
				#define UNIVERSAL_DEPTH_ONLY_PASS_INCLUDED

				#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

				struct Attributes
				{
					float4 position     : POSITION;
					float2 texcoord     : TEXCOORD0;
					UNITY_VERTEX_INPUT_INSTANCE_ID
				};

				struct Varyings
				{
					float2 uv           : TEXCOORD0;
					float4 positionCS   : SV_POSITION;
					UNITY_VERTEX_INPUT_INSTANCE_ID
						UNITY_VERTEX_OUTPUT_STEREO
				};

				Varyings DepthOnlyVertex(Attributes input)
				{
					Varyings output = (Varyings)0;
					UNITY_SETUP_INSTANCE_ID(input);
					UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

					output.uv = TRANSFORM_TEX(input.texcoord, _BaseMap);
					output.positionCS = TransformObjectToHClip(input.position.xyz);
					return output;
				}

				half4 DepthOnlyFragment(Varyings input) : SV_TARGET
				{
					UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

					Alpha(SampleAlbedoAlpha(input.uv, TEXTURE2D_ARGS(_BaseMap, sampler_BaseMap)).a, _BaseColor, _Cutoff);
					return 0;
				}
				#endif
				ENDHLSL
		}

		// This pass it not used during regular rendering, only for lightmap baking.
		Pass
		{
				Name "Meta"
				Tags{"LightMode" = "Meta"}

				Cull Off

				HLSLPROGRAM
				// Required to compile gles 2.0 with standard srp library
				#pragma prefer_hlslcc gles
				#pragma exclude_renderers d3d11_9x

				#pragma vertex UniversalVertexMeta
				#pragma fragment UniversalFragmentMeta

				#pragma shader_feature _SPECULAR_SETUP
				#pragma shader_feature _EMISSION
				#pragma shader_feature _METALLICSPECGLOSSMAP
				#pragma shader_feature _ALPHATEST_ON
				#pragma shader_feature _ _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A

				#pragma shader_feature _SPECGLOSSMAP

				#include "Assets/Common/LitInput.hlsl"
				#ifndef UNIVERSAL_LIT_META_PASS_INCLUDED
				#define UNIVERSAL_LIT_META_PASS_INCLUDED

				#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/MetaInput.hlsl"

				struct Attributes
				{
					float4 positionOS   : POSITION;
					float3 normalOS     : NORMAL;
					float2 uv0          : TEXCOORD0;
					float2 uv1          : TEXCOORD1;
					float2 uv2          : TEXCOORD2;
					#ifdef _TANGENT_TO_WORLD
					float4 tangentOS     : TANGENT;
					#endif
				};

				struct Varyings
				{
					float4 positionCS   : SV_POSITION;
					float2 uv           : TEXCOORD0;
				};

				Varyings UniversalVertexMeta(Attributes input)
				{
					Varyings output;
					output.positionCS = MetaVertexPosition(input.positionOS, input.uv1, input.uv2, unity_LightmapST, unity_DynamicLightmapST);
					output.uv = TRANSFORM_TEX(input.uv0, _BaseMap);
					return output;
				}

				half4 UniversalFragmentMeta(Varyings input) : SV_Target
				{
					SurfaceData surfaceData;
					InitializeStandardLitSurfaceData(input.uv, surfaceData);

					BRDFData brdfData;
					InitializeBRDFData(surfaceData.albedo, surfaceData.metallic, surfaceData.specular, surfaceData.smoothness, surfaceData.alpha, brdfData);

					MetaInput metaInput;
					metaInput.Albedo = brdfData.diffuse + brdfData.specular * brdfData.roughness * 0.5;
					metaInput.SpecularColor = surfaceData.specular;
					metaInput.Emission = surfaceData.emission;

					return MetaFragment(metaInput);
				}

				//LWRP -> Universal Backwards Compatibility
				Varyings LightweightVertexMeta(Attributes input)
				{
					return UniversalVertexMeta(input);
				}

				half4 LightweightFragmentMeta(Varyings input) : SV_Target
				{
					return UniversalFragmentMeta(input);
				}
				#endif
				ENDHLSL
		}

			Pass
			{
				Name "Universal2D"
				Tags{ "LightMode" = "Universal2D" }

				Blend[_SrcBlend][_DstBlend]
				ZWrite[_ZWrite]
				Cull[_Cull]

				HLSLPROGRAM
				// Required to compile gles 2.0 with standard srp library
				#pragma prefer_hlslcc gles
				#pragma exclude_renderers d3d11_9x

				#pragma vertex vert
				#pragma fragment frag
				#pragma shader_feature _ALPHATEST_ON
				#pragma shader_feature _ALPHAPREMULTIPLY_ON

				#include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
				#include "Packages/com.unity.render-pipelines.universal/Shaders/Utils/Universal2D.hlsl"
				ENDHLSL
			}
	}
	FallBack "Hidden/Universal Render Pipeline/FallbackError"
	CustomEditor "UnityEditor.Rendering.Universal.ShaderGUI.LitShaderOverride"
}
