package io.cubyz.base;

import java.io.File;
import java.io.FileReader;
import java.io.IOException;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.Map.Entry;
import java.util.Properties;

import io.cubyz.api.CubyzRegistries;
import io.cubyz.api.EventHandler;
import io.cubyz.api.LoadOrder;
import io.cubyz.api.Mod;
import io.cubyz.api.Order;
import io.cubyz.api.Proxy;
import io.cubyz.api.Registry;
import io.cubyz.api.Resource;
import io.cubyz.blocks.Block;
import io.cubyz.blocks.Block.BlockClass;
import io.cubyz.blocks.Ore;
import io.cubyz.items.Item;
import io.cubyz.items.ItemBlock;

/**
 * Mod used to support add-ons: simple mods without any sort of coding required
 */
@Mod(id = "addons-loader", name = "Addons Loader")
@LoadOrder(order = Order.AFTER, id = "cubyz")
public class AddonsMod {
	
	@Proxy(clientProxy = "io.cubyz.base.AddonsClientProxy", serverProxy = "io.cubyz.base.AddonsCommonProxy")
	private AddonsCommonProxy proxy;
	
	public ArrayList<File> addons = new ArrayList<>();
	private ArrayList<Item> items = new ArrayList<>();
	private HashMap<Block, String> missingBlockDrops = new HashMap<Block, String>();
	
	@EventHandler(type = "init")
	public void init() {
		proxy.init(this);
		registerBlockDrops();
	}
	
	@EventHandler(type = "preInit")
	public void preInit() {
		File dir = new File("addons");
		if (!dir.exists()) {
			dir.mkdir();
		}
		for (File addonDir : dir.listFiles()) {
			if (addonDir.isDirectory()) {
				addons.add(addonDir);
			}
		}
	}
	
	@EventHandler(type = "register:item")
	public void registerItems(Registry<Item> registry) {
		for (File addon : addons) {
			File items = new File(addon, "items");
			if (items.exists()) {
				for (File descriptor : items.listFiles()) {
					Properties props = new Properties();
					try {
						FileReader reader = new FileReader(descriptor);
						props.load(reader);
						reader.close();
					} catch (IOException e) {
						e.printStackTrace();
					}
					
					Item item = new Item();
					String id = descriptor.getName();
					if(id.contains("."))
						id = id.substring(0, id.indexOf('.'));
					item.setID(new Resource(addon.getName(), id));
					item.setTexture(props.getProperty("texture", "default.png"));
					registry.register(item);
				}
			}
		}
		registry.registerAll(items);
	}
	
	@EventHandler(type = "register:block")
	public void registerBlocks(Registry<Block> registry) {
		for (File addon : addons) {
			File blocks = new File(addon, "blocks");
			if (blocks.exists()) {
				for (File descriptor : blocks.listFiles()) {
					Properties props = new Properties();
					try {
						FileReader reader = new FileReader(descriptor);
						props.load(reader);
						reader.close();
					} catch (IOException e) {
						e.printStackTrace();
					}
					
					Block block;
					String id = descriptor.getName();
					if(id.contains("."))
						id = id.substring(0, id.indexOf('.'));
					String blockClass = props.getProperty("class", "STONE").toUpperCase();
					if(blockClass.equals("ORE")) { // Ores:
						float veins = Float.parseFloat(props.getProperty("veins", "0"));
						float size = Float.parseFloat(props.getProperty("size", "0"));
						int height = Integer.parseUnsignedInt(props.getProperty("height", "0"));
						Ore ore = new Ore(height, veins, size);
						block = ore;
						blockClass = "STONE";
					} else {
						block = new Block();
					}
					block.setID(new Resource(addon.getName(), id));
					block.setHardness(Float.parseFloat(props.getProperty("hardness", "1")));
					block.setBlockClass(BlockClass.valueOf(blockClass));
					block.setLight(Integer.parseUnsignedInt(props.getProperty("emittedLight", "0")));
					block.setAbsorption(Integer.decode(props.getProperty("absorbedLight", "0")));
					block.setTransparent(props.getProperty("transparent", "no").equalsIgnoreCase("yes"));
					block.setDegradable(props.getProperty("degradable", "no").equalsIgnoreCase("yes"));
					block.setSelectable(props.getProperty("selectable", "yes").equalsIgnoreCase("yes"));
					block.setSolid(props.getProperty("solid", "yes").equalsIgnoreCase("yes"));
					block.setGUI(props.getProperty("GUI", null));
					String blockDrop = props.getProperty("drop", "none").toLowerCase();
					if(blockDrop.equals("auto")) {
						ItemBlock itemBlock = new ItemBlock(block);
						block.setBlockDrop(itemBlock);
						items.add(itemBlock);
					} else if(!blockDrop.equals("none")) {
						missingBlockDrops.put(block, blockDrop);
					}
					registry.register(block);
				}
			}
		}
	}
	
	public void registerBlockDrops() {
		for(Entry<Block, String> entry : missingBlockDrops.entrySet().toArray(new Entry[0])) {
			entry.getKey().setBlockDrop(CubyzRegistries.ITEM_REGISTRY.getByID(entry.getValue()));
		}
		missingBlockDrops.clear();
	}
}