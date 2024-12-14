#include "FrameResource.h"


FrameResource::FrameResource(ID3D12Device* device, UINT passCount, UINT objectCount)
{
	ThrowIfFailed(device->CreateCommandAllocator(
		D3D12_COMMAND_LIST_TYPE_DIRECT,
		IID_PPV_ARGS(CmdListAlloc.GetAddressOf())
	));

	PassCB = std::make_unique<UploadBuffer<PassConstants>>(device, passCount, true);
	ObjectCB = std::make_unique<UploadBuffer<ObjectConstants>>(device, objectCount, true);
}

FrameResource::FrameResource(ID3D12Device* device, UINT passCount, UINT objectCount, UINT vertCount, InitializeType flag)
{
	ThrowIfFailed(device->CreateCommandAllocator(
		D3D12_COMMAND_LIST_TYPE_DIRECT,
		IID_PPV_ARGS(CmdListAlloc.GetAddressOf())
	));

	PassCB = std::make_unique<UploadBuffer<PassConstants>>(device, passCount, true);
	ObjectCB = std::make_unique<UploadBuffer<ObjectConstants>>(device, objectCount, true);

	if (flag == InitializeType::material)
	{
		MaterialCB = std::make_unique<UploadBuffer<MaterialConstants>>(device, vertCount, true);
	}
	else if (flag == InitializeType::wave)
	{
		WavesVB = std::make_unique<UploadBuffer<Vertex>>(device, vertCount, false);
	}
	else if (flag == InitializeType::instance)
	{
		MaterialBuffer = std::make_unique<UploadBuffer<MaterialData>>(device, vertCount, false);
		InstanceBuffer = std::make_unique<UploadBuffer<InstanceData>>(device, objectCount, false);
	}
	else if (flag == InitializeType::materialData)
	{
		MaterialBuffer = std::make_unique<UploadBuffer<MaterialData>>(device, vertCount, false);
	}
	else	// InitializeType::ssao
	{
		MaterialBuffer = std::make_unique<UploadBuffer<MaterialData>>(device, vertCount, false);
		SsaoCB = std::make_unique<UploadBuffer<SsaoConstants>>(device, 1, true);
	}
}

FrameResource::FrameResource(ID3D12Device* device, UINT passCount, UINT objectCount, UINT materialCount, UINT waveVertCount)
{
	ThrowIfFailed(device->CreateCommandAllocator(
		D3D12_COMMAND_LIST_TYPE_DIRECT,
		IID_PPV_ARGS(CmdListAlloc.GetAddressOf())
	));

	PassCB = std::make_unique<UploadBuffer<PassConstants>>(device, passCount, true);
	ObjectCB = std::make_unique<UploadBuffer<ObjectConstants>>(device, objectCount, true);
	MaterialCB = std::make_unique<UploadBuffer<MaterialConstants>>(device, materialCount, true);

	WavesVB = std::make_unique<UploadBuffer<Vertex>>(device, waveVertCount, false);
}

FrameResource::~FrameResource() {}
