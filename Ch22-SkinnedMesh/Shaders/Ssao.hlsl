cbuffer cbSsao : register(b0)
{
    float4x4 gProj;
    float4x4 gInvProj;
    float4x4 gProjTex;
    float4 gOffsetVectors[14];

    // For SsaoBlur.hlsl
    float4 gBlurWeights[3];

    float2 gInvRenderTargetSize;

    // Coordinates given in view space.
    float gOcclusionRadius;
    float gOcclusionFadeStart;
    float gOcclusionFadeEnd;
    float gSurfaceEpsilon;
};


Texture2D gNormalMap : register(t0);
Texture2D gDepthMap : register(t1);
Texture2D gRandomVecMap : register(t2);

SamplerState gsamPointClamp : register(s0);
SamplerState gsamLinearClamp : register(s1);
SamplerState gsamDepthMap : register(s2);
SamplerState gsamLinearWrap : register(s3);


static const int gSampleCount = 14;

static const float2 gTexCoords[6] =
{
    float2(0.0f, 1.0f),
    float2(0.0f, 0.0f),
    float2(1.0f, 0.0f),
    float2(0.0f, 1.0f),
    float2(1.0f, 0.0f),
    float2(1.0f, 1.0f)
};


struct VertexOut
{
    float4 PosH : SV_Position;
    float3 PosV : POSITION;
    float2 TexC : TEXCOORD0;
};


// 利用构成四边形的 6 个顶点进行绘制调用
VertexOut VS(uint vid : SV_VertexID)
{
    VertexOut vout;
    
    vout.TexC = gTexCoords[vid];

    // 将展示在屏幕上的全屏四边形变换至 NDC 空间
    vout.PosH = float4(2.0f * vout.TexC.x - 1.0f, 1.0f - 2.0f * vout.TexC.y, 0.0f, 1.0f);

    // 将四边形的各角点变换道观察空间的近平面
    float4 ph = mul(vout.PosH, gInvProj);
    vout.PosV = ph.xyz / ph.w;
    
    return vout;
}


// Determines how much the sample point q occludes the point p as a function of distZ.
float OcclusionFunction(float distZ)
{
	// If depth(q) is "behind" depth(p), then q cannot occlude p.
    // Moreover, if depth(q) and depth(p) are sufficiently close,
    // then we also assume q cannot occlude p
    // because q needs to be in front of p by Epsilon to occlude p.

    float occlusion = 0.0f;
    if (distZ > gSurfaceEpsilon)
    {
        float fadeLength = gOcclusionFadeEnd - gOcclusionFadeStart;

		// Linearly decrease occlusion from 1 to 0 as distZ goes 
		// from gOcclusionFadeStart to gOcclusionFadeEnd.
        occlusion = saturate((gOcclusionFadeEnd - distZ) / fadeLength);
    }
    return occlusion;
}


float NdcDepthToViewDepth(float z_ndc)
{
    // z_ndc = A + B / viewZ
    // where gProj[2,2]=A and gProj[3,2]=B
    float viewZ = gProj[3][2] / (z_ndc - gProj[2][2]);
    return viewZ;
}


float4 PS(VertexOut pin) : SV_Target
{
	// p -- the point we are computing the ambient occlusion for.
	// n -- normal vector at p.
	// q -- a random offset from p.
	// r -- a potential occluder that might occlude p.

    // Get viewspace normal and z-coord of this pixel
    float3 n = normalize(gNormalMap.SampleLevel(gsamPointClamp, pin.TexC, 0.0f).xyz);
    float pz = gDepthMap.SampleLevel(gsamDepthMap, pin.TexC, 0.0f).r;
    pz = NdcDepthToViewDepth(pz);

    float3 p = (pz / pin.PosV.z) * pin.PosV;

    // Extract random vector and map from [0,1] --> [-1, +1].
    float3 randVec = 2.0f * gRandomVecMap.SampleLevel(gsamLinearWrap, 4.0f * pin.TexC, 0.0f).rgb - 1.0f;

    float occlusionSum = 0.0f;

    [unroll]
    for (int i = 0; i < gSampleCount; ++i)
    {
        // 偏移向量都是固定且均匀分布的 (所以我们采用的偏移向量不会在同一方向上扎堆)
        // 如果将它们关于一个随机向量进行反射, 则会得到一组均匀分布的随机偏移向量
        float3 offset = reflect(gOffsetVectors[i].xyz, randVec);

        // 如果此偏移向量位于 (p,n) 平面之后, 则翻转该偏移向量
        float flip = sign(dot(offset, n));

        // 在遮蔽半径内采样靠近 p 的 q 点
        float3 q = p + flip * gOcclusionRadius * offset;

        // 投影 q 并生成对应的投影纹理坐标
        float4 projQ = mul(float4(q, 1.0f), gProjTex);
        projQ /= projQ.w;

        // 沿着从观察点至点 q 的光线, 寻找离观察点最近的深度值
        float rz = gDepthMap.SampleLevel(gsamDepthMap, projQ.xy, 0.0f).r;
        rz = NdcDepthToViewDepth(rz);

        float3 r = (rz / q.z) * q;

		// Test whether r occludes p.
		//   * The product dot(n, normalize(r - p)) measures how much in front
		//     of the plane(p,n) the occluder point r is.  The more in front it is, the
		//     more occlusion weight we give it.  This also prevents self shadowing where 
		//     a point r on an angled plane (p,n) could give a false occlusion since they
		//     have different depth values with respect to the eye.
		//   * The weight of the occlusion is scaled based on how far the occluder is from
		//     the point we are computing the occlusion of.  If the occluder r is far away
		//     from p, then it does not occlude it.
        float distZ = p.z - r.z;
        float dp = max(dot(n, normalize(r - p)), 0.0f);
        float occlusion = dp * OcclusionFunction(distZ);

        occlusionSum += occlusion;
    }

    occlusionSum /= gSampleCount;
    float access = 1.0f - occlusionSum;
    
    // 增强 SSAO 图的对比度, 使其效果更明显
    return saturate(pow(access, 2.0f));
}
