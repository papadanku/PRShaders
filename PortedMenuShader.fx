
/*
	Description: Shader that handles BF2's UI elements
*/

/*
	[Attributes from app]
*/

// [1] Render-state settings from app
uniform bool _AlphaBlend : ALPHABLEND = false;
uniform dword _SrcBlend : SRCBLEND = D3DBLEND_INVSRCALPHA;
uniform dword _DestBlend : DESTBLEND = D3DBLEND_SRCALPHA;
uniform bool _AlphaTest : ALPHATEST = false;
uniform dword _AlphaFunc : ALPHAFUNC = D3DCMP_GREATER;
uniform dword _AlphaRef : ALPHAREF = 0;
uniform dword _ZEnable : ZMODE = D3DZB_TRUE;
uniform dword _ZFunc : ZFUNC = D3DCMP_LESSEQUAL;
uniform bool _ZWriteEnable : ZWRITEENABLE = true;

uniform float4x4 _WorldMatrix : matWORLD;
uniform float4x4 _ViewMatrix : matVIEW;
uniform float4x4 _ProjMatrix : matPROJ;

/*
	[Textures and samplers]
*/

uniform texture Tex0: TEXLAYER0;
sampler SampleTex0 = sampler_state
{
	Texture = (Tex0);
	AddressU = CLAMP;
	AddressV = CLAMP;
	MinFilter = LINEAR;
	MagFilter = LINEAR;
	MipFilter = LINEAR;
	SRGBTexture = FALSE;
};

uniform texture Tex1: TEXLAYER1;
sampler SampleTex1 = sampler_state
{
	Texture = (Tex1);
	AddressU = CLAMP;
	AddressV = CLAMP;
	MinFilter = LINEAR;
	MagFilter = LINEAR;
	MipFilter = LINEAR;
	SRGBTexture = FALSE;
};

struct APP2VS
{
	float4 Pos : POSITION;
	float4 Color : COLOR;
	float2 TexCoord0 : TEXCOORD0;
	float2 TexCoord1 : TEXCOORD1;
};

struct VS2PS
{
	float4 HPos : POSITION;
	float4 Color : COLOR0;
	float2 TexCoord0 : TEXCOORD0;
	float2 TexCoord1 : TEXCOORD1;
};

VS2PS Basic_VS(APP2VS Input)
{
	VS2PS Output;
	float4x4 WorldViewProj = _WorldMatrix * _ViewMatrix * _ProjMatrix;
	Output.HPos = mul(Input.Pos, WorldViewProj);
	Output.Color = saturate(Input.Color);
 	Output.TexCoord0 = Input.TexCoord0;
 	Output.TexCoord1 = Input.TexCoord1;
	return Output;
}

technique Menu
{
	pass { }
}

technique Menu_States <bool Restore = true;>
{
	pass BeginStates { }
	pass EndStates { }
}

float4 Quad_WTex_NoTex_PS(VS2PS Input) : COLOR
{
	return Input.Color;
}

float4 Quad_WTex_Tex_PS(VS2PS Input) : COLOR
{
	return Input.Color * tex2D(SampleTex0, Input.TexCoord0);
}

float4 Quad_WTex_Tex_Masked_PS(VS2PS Input) : COLOR
{
	float4 Color = Input.Color * tex2D(SampleTex0, Input.TexCoord0);
	// Color *= tex2D(SampleTex1, Input.TexCoord1);
	Color.a *= tex2D(SampleTex1, Input.TexCoord1).a;
	return Color;
}

// Macro for app render-state settings from [1]
#define APP_ALPHA_DEPTH_SETTINGS \
	AlphaBlendEnable = (_AlphaBlend); \
	SrcBlend = (_SrcBlend); \
	DestBlend = (_DestBlend); \
	AlphaTestEnable = (_AlphaTest); \
	AlphaFunc = (_AlphaFunc); \
	AlphaRef = (_AlphaRef); \
	ZEnable = (_ZEnable); \
	ZFunc = (_ZFunc); \
	ZWriteEnable = (_ZWriteEnable); \
	SRGBWriteEnable = FALSE; \

technique QuadWithTexture
<
	int Declaration[] =
	{
		// StreamNo, DataType, Usage, UsageIdx
		0, D3DDECLTYPE_FLOAT3, D3DDECLUSAGE_POSITION, 0,
		0, D3DDECLTYPE_FLOAT4, D3DDECLUSAGE_COLOR, 0,
		0, D3DDECLTYPE_FLOAT2, D3DDECLUSAGE_TEXCOORD, 0,
		0, D3DDECLTYPE_FLOAT2, D3DDECLUSAGE_TEXCOORD, 1,
		DECLARATION_END	// End macro
	};
>
{
	pass NoTex
	{
		// App alpha/depth settings
		APP_ALPHA_DEPTH_SETTINGS
		VertexShader = compile vs_3_0 Basic_VS();
		PixelShader = compile ps_3_0 Quad_WTex_NoTex_PS();
	}

	pass Tex
	{
		// App alpha/depth settings
		APP_ALPHA_DEPTH_SETTINGS
		VertexShader = compile vs_3_0 Basic_VS();
		PixelShader = compile ps_3_0 Quad_WTex_Tex_PS();
	}

	pass Masked
	{
		// App alpha/depth settings
		APP_ALPHA_DEPTH_SETTINGS
		VertexShader = compile vs_3_0 Basic_VS();
		PixelShader = compile ps_3_0 Quad_WTex_Tex_Masked_PS();
	}
}

float4 Quad_Cache_PS(VS2PS Input) : COLOR
{
	float4 InputTexture = tex2D(SampleTex0, Input.TexCoord0);
	return (InputTexture + 1.0) * Input.Color;
}

technique QuadCache
<
	int Declaration[] =
	{
		// StreamNo, DataType, Usage, UsageIdx
		0, D3DDECLTYPE_FLOAT4, D3DDECLUSAGE_POSITION, 0,
		0, D3DDECLTYPE_FLOAT4, D3DDECLUSAGE_COLOR, 0,
		0, D3DDECLTYPE_FLOAT2, D3DDECLUSAGE_TEXCOORD, 0,
		0, D3DDECLTYPE_FLOAT2, D3DDECLUSAGE_TEXCOORD, 1,
		DECLARATION_END	// End macro
	};
>
{
	pass Pass0
	{
		AlphaBlendEnable = FALSE;

		AlphaTestEnable = TRUE;
		AlphaFunc = GREATER;
		AlphaRef = 0;

		ZEnable = TRUE;
		ZFunc = LESS;
		ZWriteEnable = TRUE;

		SRGBWriteEnable = FALSE;

		VertexShader = compile vs_3_0 Basic_VS();
		PixelShader = compile ps_3_0 Quad_Cache_PS();
	}
}
