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

FrameResource::FrameResource(ID3D12Device* device, UINT passCount, UINT objectCount, UINT count1, InitializeType flag)
{
	ThrowIfFailed(device->CreateCommandAllocator(
		D3D12_COMMAND_LIST_TYPE_DIRECT,
		IID_PPV_ARGS(CmdListAlloc.GetAddressOf())
	));

	PassCB = std::make_unique<UploadBuffer<PassConstants>>(device, passCount, true);
	ObjectCB = std::make_unique<UploadBuffer<ObjectConstants>>(device, objectCount, true);

	if (flag == InitializeType::material)
	{
		MaterialCB = std::make_unique<UploadBuffer<MaterialConstants>>(device, count1, true);
	}
	else if (flag == InitializeType::wave)
	{
		WavesVB = std::make_unique<UploadBuffer<Vertex>>(device, count1, false);
	}
	else if (flag == InitializeType::instance)
	{
		MaterialBuffer = std::make_unique<UploadBuffer<MaterialData>>(device, count1, false);
		InstanceBuffer = std::make_unique<UploadBuffer<InstanceData>>(device, objectCount, false);
	}
	else if (flag == InitializeType::materialData)
	{
		MaterialBuffer = std::make_unique<UploadBuffer<MaterialData>>(device, count1, false);
	}
	else	// InitializeType::ssao
	{
		MaterialBuffer = std::make_unique<UploadBuffer<MaterialData>>(device, count1, false);
		SsaoCB = std::make_unique<UploadBuffer<SsaoConstants>>(device, 1, true);
	}
}

FrameResource::FrameResource(ID3D12Device* device, UINT passCount, UINT objectCount, UINT count1, UINT count2, InitializeType flag)
{
	ThrowIfFailed(device->CreateCommandAllocator(
		D3D12_COMMAND_LIST_TYPE_DIRECT,
		IID_PPV_ARGS(CmdListAlloc.GetAddressOf())
	));

	PassCB = std::make_unique<UploadBuffer<PassConstants>>(device, passCount, true);
	ObjectCB = std::make_unique<UploadBuffer<ObjectConstants>>(device, objectCount, true);

	if (flag == InitializeType::wave)
	{
		MaterialCB = std::make_unique<UploadBuffer<MaterialConstants>>(device, count1, true);
		WavesVB = std::make_unique<UploadBuffer<Vertex>>(device, count2, false);
	}
	else
	{
		SsaoCB = std::make_unique<UploadBuffer<SsaoConstants>>(device, 1, true);
		SkinnedCB = std::make_unique<UploadBuffer<SkinnedConstants>>(device, count1, true);
		MaterialBuffer = std::make_unique<UploadBuffer<MaterialData>>(device, count2, false);
	}
}

FrameResource::~FrameResource() {}
