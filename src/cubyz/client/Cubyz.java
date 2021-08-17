package cubyz.client;

import java.util.ArrayDeque;
import java.util.Deque;

import org.joml.Vector3f;

import cubyz.client.rendering.Camera;
import cubyz.client.rendering.Fog;
import cubyz.client.rendering.Hud;
import cubyz.client.rendering.RenderOctTree;
import cubyz.client.rendering.Window;
import cubyz.gui.UISystem;
import cubyz.world.Surface;
import cubyz.world.World;
import cubyz.world.entity.PlayerEntity.PlayerImpl;

/**
 * A simple data holder for all static data that is needed for basic game functionality.
 */
public class Cubyz {
	// stuff for rendering:
	public static Camera camera = new Camera();
	public static Fog fog = new Fog(true, new Vector3f(0.5f, 0.5f, 0.5f), 0.025f);
	public static UISystem gameUI = new UISystem();
	public static Hud hud = new Hud();
	public static Deque<Runnable> renderDeque = new ArrayDeque<>();
	public static Window window = new Window();
	public static RenderOctTree chunkTree = new RenderOctTree();
	
	// World related stuff:
	public static Surface surface;
	public static World world;
	public static PlayerImpl player;
	
	// Other:
	public static Vector3f playerInc = new Vector3f();
	/**Selected slot in hotbar*/
	public static int inventorySelection = 0;
	public static Vector3f dir = new Vector3f();
	public static MeshSelectionDetector msd = new MeshSelectionDetector();
}