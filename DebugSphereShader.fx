
/*
	Description: Renders debug lightsource spheres
*/

#include "shaders/RealityGraphics.fxh"

float4x4 _WorldViewProj : WorldViewProjection;
float4x4 _World : World;

string Category = "Effects\\Lighting";

float4 _LightDir = { 1.0f, 0.0f, 0.0f, 1.0f }; //light Direction
float4 _LightDiffuse = { 1.0f, 1.0f, 1.0f, 1.0f }; // Light Diffuse
float4 _MaterialAmbient : MATERIALAMBIENT = { 0.5f, 0.5f, 0.5f, 1.0f };
float4 _MaterialDiffuse : MATERIALDIFFUSE = { 1.0f, 1.0f, 1.0f, 1.0f };

uniform texture BaseTex : TEXLAYER0
<
	string File = "aniso2.dds";
	string TextureType = "2D";
>;

sampler2D SampleBaseTex = sampler_state
{
	Texture = (BaseTex);
	MinFilter = LINEAR;
	MagFilter = LINEAR;
	MipFilter = LINEAR;
};

struct APP2VS
{
	float4 Pos : POSITION;
	float3 Normal : NORMAL;
	float2 TexCoord0 : TEXCOORD0;
};

struct VS2PS
{
	float4 HPos : POSITION;
	float4 Diffuse : COLOR0;
	float2 Tex0 : TEXCOORD0;
};

float3 Diffuse(float3 Normal)
{
	// N.L Clamped
	return saturate(dot(Normal, _LightDir.xyz));
}

VS2PS Debug_Basic_VS(APP2VS Input)
{
	VS2PS Output;

	float3 Pos = mul(Input.Pos, _World);
	Output.HPos = mul(float4(Pos.xyz, 1.0f), _WorldViewProj);

	// Lighting. Shade (Ambient + etc.)
	Output.Diffuse.xyz = _MaterialAmbient.xyz + Diffuse(Input.Normal) * _MaterialDiffuse.xyz;
	Output.Diffuse.w = 1.0f;

	Output.Tex0 = Input.TexCoord0;

	return Output;
}

float4 Debug_Basic_PS(VS2PS Input) : COLOR
{
	return tex2D(SampleBaseTex, Input.Tex0) * Input.Diffuse;
}

float4 Debug_Marked_PS(VS2PS Input) : COLOR
{
	return (tex2D(SampleBaseTex, Input.Tex0) * Input.Diffuse) + float4(1.0f, 0.0f, 0.0f, 0.0f);
}

technique t0_States < bool Restore = false; >
{
	pass BeginStates
	{
		CullMode = NONE;
	}
	pass EndStates
	{
		CullMode = CCW;
	}
}

technique t0
<
	int Declaration[] =
	{
		// StreamNo, DataType, Usage, UsageIdx
		{ 0, D3DDECLTYPE_FLOAT3, D3DDECLUSAGE_POSITION, 0 },
		{ 0, D3DDECLTYPE_FLOAT3, D3DDECLUSAGE_NORMAL, 0 },
		{ 0, D3DDECLTYPE_FLOAT2, D3DDECLUSAGE_TEXCOORD, 0 },
		DECLARATION_END	// End macro
	};

>
{
	pass Pass0
	{
		VertexShader = compile vs_3_0 Debug_Basic_VS();
		PixelShader = compile ps_3_0 Debug_Basic_PS();
	}
}


technique marked
<
	int DetailLevel = DLHigh+DLNormal+DLLow+DLAbysmal;
	int Compatibility = CMPR300+CMPNV2X;
	int Declaration[] =
	{
		// StreamNo, DataType, Usage, UsageIdx
		{ 0, D3DDECLTYPE_FLOAT3, D3DDECLUSAGE_POSITION, 0 },
		{ 0, D3DDECLTYPE_FLOAT3, D3DDECLUSAGE_NORMAL, 0 },
		{ 0, D3DDECLTYPE_FLOAT2, D3DDECLUSAGE_TEXCOORD, 0 },
		DECLARATION_END	// End macro
	};
>
{
	pass Pass0
	{
		CullMode = NONE;
		AlphaBlendEnable = FALSE;

		VertexShader = compile vs_3_0 Debug_Basic_VS();
		PixelShader = compile ps_3_0 Debug_Marked_PS();
	}
}

VS2PS Debug_LightSource_VS(APP2VS Input)
{
	VS2PS Output;

 	float4 Pos;
 	Pos.xyz = mul(Input.Pos, _World);
 	Pos.w = 1.0;
	Output.HPos = mul(Pos, _WorldViewProj);

	// Lighting. Shade (Ambient + etc.)
	Output.Diffuse.rgb = _MaterialDiffuse.xyz;
	Output.Diffuse.a = _MaterialDiffuse.w;

	Output.Tex0 = 0.0;

	return Output;
}

float4 Debug_LightSource_PS(VS2PS Input) : COLOR
{
	return Input.Diffuse;
}

technique lightsource
<
	int Declaration[] =
	{
		// StreamNo, DataType, Usage, UsageIdx
		{ 0, D3DDECLTYPE_FLOAT3, D3DDECLUSAGE_POSITION, 0 },
		{ 0, D3DDECLTYPE_FLOAT3, D3DDECLUSAGE_NORMAL, 0 },
		DECLARATION_END	// End macro
	};
>
{
	pass Pass0
	{
		CullMode = NONE;
		ColorWriteEnable = 0;
		AlphaBlendEnable = FALSE;

		ZFunc = LESSEQUAL;
		ZWriteEnable = TRUE;

		VertexShader = compile vs_3_0 Debug_LightSource_VS();
		PixelShader = compile ps_3_0 Debug_LightSource_PS();
	}

	pass Pass1
	{
		ColorWriteEnable = Red|Blue|Green|Alpha;

		AlphaBlendEnable = TRUE;
		SrcBlend = SRCALPHA;
		DestBlend = INVSRCALPHA;

		ZFunc = EQUAL;
		ZWriteEnable = FALSE;

		VertexShader = compile vs_3_0 Debug_LightSource_VS();
		PixelShader = compile ps_3_0 Debug_LightSource_PS();
	}
}

technique editor
<
	int Declaration[] =
	{
		// StreamNo, DataType, Usage, UsageIdx
		{ 0, D3DDECLTYPE_FLOAT3, D3DDECLUSAGE_POSITION, 0 },
		{ 0, D3DDECLTYPE_FLOAT3, D3DDECLUSAGE_NORMAL, 0 },
		DECLARATION_END	// End macro
	};
>
{
	pass Pass0
	{
		CullMode = NONE;
		ColorWriteEnable = 0;
		AlphaBlendEnable = FALSE;

		ZFunc = LESSEQUAL;
		ZWriteEnable = TRUE;

		VertexShader = compile vs_3_0 Debug_LightSource_VS();
		PixelShader = compile ps_3_0 Debug_LightSource_PS();
	}

	pass Pass1
	{
		ColorWriteEnable = Red|Blue|Green|Alpha;

		AlphaBlendEnable = TRUE;
		SrcBlend = SRCALPHA;
		DestBlend = INVSRCALPHA;

		ZFunc = EQUAL;
		ZWriteEnable = FALSE;

		VertexShader = compile vs_3_0 Debug_LightSource_VS();
		PixelShader = compile ps_3_0 Debug_LightSource_PS();
	}
}

technique EditorDebug
{
	pass Pass0
	{
		CullMode = NONE;

		AlphaBlendEnable = TRUE;
		SrcBlend = SRCALPHA;
		DestBlend = INVSRCALPHA;

		ZWriteEnable = 1;
		ZEnable = TRUE;
		ZFunc = LESSEQUAL;

		ShadeMode = FLAT;
		FillMode = SOLID;

		VertexShader = compile vs_3_0 Debug_LightSource_VS();
		PixelShader = compile ps_3_0 Debug_LightSource_PS();
	}
}
