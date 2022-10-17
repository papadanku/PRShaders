
/*
	Description:
	- Renders lighting for staticmesh (buildings, static props)
	- Calculates tangent-space lighting
*/

#include "shaders/RealityGraphics.fx"
#include "shaders/RaCommon.fx"
#include "shaders/RaShaderSTMCommon.fx"

#define SkyNormal float3(0.78, 0.52, 0.65)

// tl: Alias packed data indices to regular indices:
#if defined(TexBasePackedInd)
	#define TexBaseInd TexBasePackedInd
#endif

#if defined(TexDetailPackedInd)
	#define TexDetailInd TexDetailPackedInd
#endif

#if defined(TexDirtPackedInd)
	#define TexDirtInd TexDirtPackedInd
#endif

#if defined(TexCrackPackedInd)
	#define TexCrackInd TexCrackPackedInd
#endif

#if defined(TexLightMapPackedInd)
	#define TexLightMapInd TexLightMapPackedInd
#endif

#if (_NBASE_ || _NDETAIL_ || _NCRACK_ || _PARALLAXDETAIL_)
	#define USE_DETAIL
#else
	#define _CRACK_ 0 // We do not allow Crack if we run on the non detailed path.
#endif

// common vars
Light Lights[NUM_LIGHTS];

struct APP2VS
{
	float4 Pos : POSITION;
	float3 Normal : NORMAL;
	float3 Tan : TANGENT;
	float4 TexSets[NUM_TEXSETS] : TEXCOORD0;
};

float GetBinormalFlipping(APP2VS Input)
{
	return 1.0 + Input.Pos.w * -2.0;
}

/*
	Common vertex shader methods
*/

// P_(x)_(y) == Packed interpolator with (x) and (y)

struct VS2PS
{
	float4 HPos : POSITION;

	float3 ObjectPos : TEXCOORD0;
	float3 ObjectTangent : TEXCOORD1;
	float3 ObjectBiNormal : TEXCOORD2;
	float3 ObjectNormal : TEXCOORD3;

	float4 P_Base_Detail : TEXCOORD4; // .xy = TexBase; .zw = TexDetail;
	float4 P_Dirt_Crack : TEXCOORD5; // .xy = TexDirt; .zw = TexCrack;
	float4 LightMapTex : TEXCOORD6;
	float4 ShadowTex : TEXCOORD7;
};

VS2PS StaticMesh_VS(APP2VS Input)
{
	VS2PS Output = (VS2PS)0;

	// Get object-space properties
	float4 ObjectPos = float4(Input.Pos.xyz, 1.0) * PosUnpack;
	float3 ObjectTangent = Input.Tan * NormalUnpack.x + NormalUnpack.y; // Unpack object-space tangent
	float3 ObjectNormal = Input.Normal * NormalUnpack.x + NormalUnpack.y; // Unpack object-space normal
	float3x3 ObjectTBN = GetTangentBasis(ObjectTangent, ObjectNormal, GetBinormalFlipping(Input));

	// Output HPos
	Output.HPos = mul(ObjectPos, WorldViewProjection);

	// Output object-space properties
	Output.ObjectPos = ObjectPos.xyz;
	Output.ObjectTangent = ObjectTBN[0];
	Output.ObjectBiNormal = ObjectTBN[1];
	Output.ObjectNormal = ObjectTBN[2];

	#if _BASE_
		Output.P_Base_Detail.xy = Input.TexSets[TexBaseInd].xy * TexUnpack;
	#endif
	#if _DETAIL_ || _NDETAIL_
		Output.P_Base_Detail.zw = Input.TexSets[TexDetailInd].xy * TexUnpack;
	#endif

	#if _DIRT_
		Output.P_Dirt_Crack.xy = Input.TexSets[TexDirtInd].xy * TexUnpack;
	#endif
	#if _CRACK_
		Output.P_Dirt_Crack.zw = Input.TexSets[TexCrackInd].xy * TexUnpack;
	#endif

	#if	_LIGHTMAP_
		Output.LightMapTex.xy =  Input.TexSets[TexLightMapInd].xy * TexUnpack * LightMapOffset.xy + LightMapOffset.zw;
	#endif

	#if _SHADOW_ && _LIGHTMAP_
		Output.ShadowTex = GetShadowProjection(ObjectPos);
	#endif

	return Output;
}

float2 CalcParallax(float2 HeightTexCoords, sampler2D HeightSampler, float4 ScaleBias, float3 ViewVec)
{
	float2 Height = tex2D(HeightSampler, HeightTexCoords).aa;
	float2 EyeVecN = ViewVec.xy * float2(1.0, -1.0);
	float4 FakeBias = float4(FH2_HARDCODED_PARALLAX_BIAS, FH2_HARDCODED_PARALLAX_BIAS, 0.0, 0.0);
	Height = Height * FakeBias.xy + FakeBias.wz;
	return HeightTexCoords + Height * EyeVecN.xy;
}

float4 GetCompositeDiffuse(VS2PS Input, float3 TanEyeVec, out float Gloss)
{
	float4 Diffuse = 0.0;
	Gloss = StaticGloss;

	#if _BASE_
		Diffuse = tex2D(DiffuseMapSampler, Input.P_Base_Detail.xy);
	#endif

	#if _PARALLAXDETAIL_
		float4 Detail = tex2D(DetailMapSampler, CalcParallax(Input.P_Base_Detail.zw, NormalMapSampler, ParallaxScaleBias, TanEyeVec));
	#elif _DETAIL_
		float4 Detail = tex2D(DetailMapSampler, Input.P_Base_Detail.zw);
	#endif

	#if (_DETAIL_ || _PARALLAXDETAIL_)
		// tl: assumes base has .a = 1 (which should be the case)
		// Diffuse.rgb *= Detail.rgb;
		Diffuse *= Detail;
		#if (!_ALPHATEST_)
			Gloss = Detail.a;
			Diffuse.a = Transparency.a;
		#else
			Diffuse.a *= Transparency.a;
		#endif
	#else
		Diffuse.a *= Transparency.a;
	#endif

	#if _DIRT_
		Diffuse.rgb *= tex2D(DirtMapSampler, Input.P_Dirt_Crack.xy).rgb;
	#endif

	#if _CRACK_
		float4 Crack = tex2D(CrackMapSampler, Input.P_Dirt_Crack.zw);
		Diffuse.rgb = lerp(Diffuse.rgb, Crack.rgb, Crack.a);
	#endif

	return Diffuse;
}

// This also includes the composite Gloss map
float3 GetCompositeNormals(VS2PS Input, float3 TanEyeVec)
{
	float3 Normals = 0.0;

	#if	_NBASE_
		Normals = tex2D(NormalMapSampler, Input.P_Base_Detail.xy);
	#endif

	#if _PARALLAXDETAIL_
		Normals = tex2D(NormalMapSampler, CalcParallax(Input.P_Base_Detail.zw, NormalMapSampler, ParallaxScaleBias, TanEyeVec));
	#elif _NDETAIL_
		Normals = tex2D(NormalMapSampler, Input.P_Base_Detail.zw);
	#endif

	#if _NCRACK_
		float4 CrackNormal = tex2D(CrackNormalMapSampler, Input.P_Dirt_Crack.zw);
		float CrackMask = tex2D(CrackMapSampler, Input.P_Dirt_Crack.zw).a;
		Normals = lerp(Normals, CrackNormal.rgb, CrackMask);
	#endif

	return Normals * 2.0 - 1.0;
}

float3 GetLightmap(VS2PS Input)
{
	#if _LIGHTMAP_
		return tex2D(LightMapSampler, Input.LightMapTex.xy).rgb;
	#else
		return 1.0;
	#endif
}

float3 GetLightVec(float3 ObjectPos)
{
	#if _POINTLIGHT_
		return Lights[0].pos - ObjectPos;
	#else
		return -Lights[0].dir;
	#endif
}

float4 StaticMesh_PS(VS2PS Input) : COLOR
{
	// Get object-space properties
	float3 ObjectPos = Input.ObjectPos;
	float3 ObjectTangent = normalize(Input.ObjectTangent);
	float3 ObjectBiNormal = normalize(Input.ObjectBiNormal);
	float3 ObjectNormal = normalize(Input.ObjectNormal);
	float3x3 ObjI = transpose(float3x3(ObjectTangent, ObjectBiNormal, ObjectNormal));

	// Get tangent-space vectors
	float3 LightVec = normalize(mul(GetLightVec(ObjectPos), ObjI));
	float3 ViewVec = normalize(mul(ObjectSpaceCamPos - ObjectPos, ObjI));
	float3 HalfVec = normalize(LightVec + ViewVec);

	#if defined(USE_DETAIL)
		float3 Normals = normalize(GetCompositeNormals(Input, ViewVec));
	#else
		float3 Normals = float3(0.0, 0.0, 1.0);
	#endif

	float4 OutputColor = 1.0;

	float Gloss;
	float4 DiffuseTex = GetCompositeDiffuse(Input, ViewVec, Gloss);

	float Diffuse = GetDiffuse(Normals, LightVec);
	float Specular = GetSpecular(Diffuse, Normals, HalfVec) * Gloss;

	float3 DiffuseColor = Diffuse * Lights[0].color;
	float3 SpecularColor = Specular * StaticSpecularColor;

	#if _POINTLIGHT_
		float Attenuation = GetLightAttenuation(GetLightVec(ObjectPos), Lights[0].attenuation);
		float3 Lighting = (DiffuseColor + SpecularColor) * Attenuation;
		OutputColor.rgb = (DiffuseTex.rgb * Lighting) * GetFogValue(ObjectPos, ObjectSpaceCamPos);
	#else
		// Directional light + Lightmap etc
		float3 Lightmap = GetLightmap(Input);
		float3 Ambient = SinglePointColor * Lightmap.r;

		#if defined(USE_DETAIL)
			// Pre-calc: Lightmap.b *= invDot
			float3 BumpedSky = Lightmap.b * dot(Normals, SkyNormal) * StaticSkyColor;
			// tl: Jonas, disable once we know which materials are actually affected.
			DiffuseColor = ((DiffuseColor * Lightmap.g) + BumpedSky) + Ambient;
		#else
			float DotLN = saturate(dot(Normals * 0.2, -Lights[0].dir));
			float3 InvDot = saturate(saturate(1.0 - DotLN) * StaticSkyColor.rgb * SkyNormal.z);
			#if _LIGHTMAP_
				// Add ambient here as well to get correct ambient for surfaces parallel to the sun
				float3 BumpedSky = InvDot * Lightmap.b;
				float3 BumpedDiffuse = DiffuseColor + BumpedSky;
				DiffuseColor = lerp(BumpedSky, BumpedDiffuse, Lightmap.g) + Ambient;
			#else
				float3 BumpedSky = InvDot;
				DiffuseColor = (DiffuseColor * Lightmap.g) + BumpedSky;
			#endif
		#endif

		OutputColor.rgb = DiffuseTex.rgb * ((DiffuseColor * 2.0) + (SpecularColor * Lightmap.g));
	#endif

	#if !_POINTLIGHT_
		OutputColor.rgb = ApplyFog(OutputColor.rgb, GetFogValue(ObjectPos, ObjectSpaceCamPos));
	#endif

	OutputColor.a = DiffuseTex.a;

	return OutputColor;
};

technique defaultTechnique
{
	pass P0
	{
		ZFunc = LESS;

		#if defined(ENABLE_WIREFRAME)
			FillMode = WireFrame;
		#endif

		#if _POINTLIGHT_
			ZFunc = LESSEQUAL;
			AlphaBlendEnable = TRUE;
			SrcBlend = ONE;
			DestBlend = ONE;
		#endif

		AlphaTestEnable = < AlphaTest >;
		AlphaRef = 127; // temporary hack by johan because "m_shaderSettings.m_alphaTestRef = 127" somehow doesn't work

		VertexShader = compile vs_3_0 StaticMesh_VS();
		PixelShader = compile ps_3_0 StaticMesh_PS();
	}
}
