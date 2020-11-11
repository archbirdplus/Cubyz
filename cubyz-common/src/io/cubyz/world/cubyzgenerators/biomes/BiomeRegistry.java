package io.cubyz.world.cubyzgenerators.biomes;

import java.util.ArrayList;
import java.util.HashMap;

import io.cubyz.api.Registry;

public class BiomeRegistry extends Registry<Biome> {
	public HashMap<Biome.Type, ArrayList<Biome>> byTypeBiomes = new HashMap<Biome.Type, ArrayList<Biome>>();
	public BiomeRegistry() {
		for(Biome.Type type : Biome.Type.values()) {
			byTypeBiomes.put(type, new ArrayList<>());
		}
	}
	
	public BiomeRegistry(BiomeRegistry other) {
		super(other);
		for(Biome.Type type : Biome.Type.values()) {
			byTypeBiomes.put(type, new ArrayList<>(other.byTypeBiomes.get(type)));
		}
	}
	
	@Override
	public boolean register(Biome biome) {
		if(super.register(biome)) {
			byTypeBiomes.get(biome.type).add(biome);
			return true;
		}
		return false;
	}
}