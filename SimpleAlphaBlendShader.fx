
/*
	Description: Renders simple blendop shader
*/

#include "shaders/RealityGraphics.fxh"

uniform float4x4 _WorldViewProj : WorldViewProjection;

uniform texture BaseTex: TEXLAYER0
<
	string File = "aniso2.dds";
	string TextureType = "2D";
>;

sampler SampleBaseTex = sampler_state
{
	Texture = (BaseTex);
	// Target = Texture2D;
	MinFilter = LINEAR;
	MagFilter = LINEAR;
	MipFilter = LINEAR;
    AddressU = WRAP;
    AddressV = WRAP;
	SRGBTexture = FALSE;
};

struct APP2VS
{
    float4 Pos : POSITION;
    float2 Tex0 : TEXCOORD0;
};

struct VS2PS
{
    float4 HPos : POSITION;
    float2 Tex0 : TEXCOORD0;
};

VS2PS Shader_VS(APP2VS Input)
{
	VS2PS Output;
	Output.HPos = mul(float4(Input.Pos.xyz, 1.0f), _WorldViewProj);
	Output.Tex0 = Input.Tex0;
	return Output;
}

float4 Shader_PS(VS2PS Input) : COLOR
{
	return tex2D(SampleBaseTex, Input.Tex0);
}

technique t0_States <bool Restore = true;>
{
	pass BeginStates
	{
		ZEnable = TRUE;
		// MatsD 030903: Due to transparent isn't sorted yet. Write Z values
		ZWriteEnable = TRUE;
		CullMode = NONE;
		AlphaBlendEnable = TRUE;
		SrcBlend = ONE;
		DestBlend = ONE;
		// SrcBlend = SRCALPHA;
		// DestBlend = INVSRCALPHA;
	}
	
	pass EndStates { }
}

technique t0
{
	pass Pass0 
	{
		VertexShader = compile vs_3_0 Shader_VS();
		PixelShader = compile ps_3_0 Shader_PS();
	}
}

/*
	technique marked
	{
		pass Pass0
		{
			CullMode = NONE;
			AlphaBlendEnable = FALSE;
			Lighting = TRUE;
		
			VertexShader = compile vs_3_0 Shader_VS(_WorldViewProj, MaterialAmbient, MaterialDiffuse, LhtDir);
			PixelShader = compile ps_3_0 PShaderMarked(samplebase);
		}
	}
*/
