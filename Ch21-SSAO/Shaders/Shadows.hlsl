#include "Common.hlsl"


struct VertexIn
{
    float3 PosL : POSITION;
    float2 TexC : TEXCOORD;
};


struct VertexOut
{
    float4 PosH : SV_Position;

#ifdef ALPHA_TEST
    float2 TexC : TEXCOORD;
#endif
};


VertexOut VS(VertexIn vin)
{
    VertexOut vout = (VertexOut) 0.0f;

    float4 posW = mul(float4(vin.PosL, 1.0f), gWorld);
    vout.PosH = mul(posW, gViewProj);

#ifdef ALPHA_TEST
    MaterialData matData = gMaterialData[gMaterialIndex];
    float4 texC = mul(float4(vin.TexC, 0.0f, 1.0f), gTexTransform);
    vout.TexC = mul(texC, matData.MatTransform).xy;
#endif

    return vout;
}


void PS(VertexOut pin)
{
#ifdef ALPHA_TEST
    // Fetch the material data.
    MaterialData matData = gMaterialData[gMaterialIndex];
    float4 diffuseAlbedo = matData.DiffuseAlbedo;
    uint diffuseMapIndex = matData.DiffuseMapIndex;
	
	// Dynamically look up the texture in the array.
    diffuseAlbedo *= gTextureMaps[diffuseMapIndex].Sample(gsamAnisotropicWrap, pin.TexC);

    // Discard pixel if texture alpha < 0.1.
    // We do this test as soon as possible in the shader
    // so that we can potentially exit the shader early,
    // thereby skipping the rest of the shader code.
    clip(diffuseAlbedo.a - 0.1f);
#endif
}
