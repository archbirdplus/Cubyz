package server;

import cubyz.utils.Logger;
import cubyz.client.ClientSettings;
import cubyz.client.Cubyz;
import cubyz.client.entity.ClientEntityManager;
import cubyz.utils.Pacer;
import cubyz.world.NormalChunk;

public class Server{
	public static final int UPDATES_PER_SEC = 20;
	public static final int UPDATES_TIME_NS = 1_000_000_000 / UPDATES_PER_SEC;
	public static final float UPDATES_TIME_S = UPDATES_TIME_NS / 10e9f;

	//set the pacer
	public static final Pacer serverPacer = new Pacer("Server") {
		@Override
		public void update() {
			Cubyz.world.update();
			// TODO: Adjust for multiple players:
			Cubyz.world.clientConnection.serverPing(Cubyz.world.getGameTime(), Cubyz.world.getBiome((int)Cubyz.player.getPosition().x, (int)Cubyz.player.getPosition().z).getRegistryID().toString());
			// TODO: Move this to the client, or generalize this for multiplayer.
			Cubyz.world.seek((int)Cubyz.player.getPosition().x, (int)Cubyz.player.getPosition().y, (int)Cubyz.player.getPosition().z, ClientSettings.RENDER_DISTANCE, ClientSettings.EFFECTIVE_RENDER_DISTANCE*NormalChunk.chunkSize*2);

			// TODO: Send this through the proper interface and to every player:
			ClientEntityManager.serverUpdate(Cubyz.world.getEntities());
		}
	};
	public static void main(String[] args) {
		try {
			while(Cubyz.world == null) {
				// TODO: Init world here.
				Thread.sleep(10);
			}
			serverPacer.setFrequency(UPDATES_PER_SEC);
			serverPacer.start();
		} catch (Exception e) {
			Logger.crash(e);
		}
	}
	public static void stop(){
		if(serverPacer!=null)
			serverPacer.running = false;
	}
}
