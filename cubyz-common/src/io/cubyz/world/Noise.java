package io.cubyz.world;

import java.util.Random;

/**
 * Fractal Noise Generator for world generation.
 * @author IntegratedQuantum
 */
public class Noise {
	static long getSeed(int x, int y, int offsetX, int offsetY, int worldAnd, long seed) {
		return (((long)((offsetX+x) & worldAnd)) << 16)^seed^(((long)((offsetY+y) & worldAnd)) << 32);
	}
	public static float[][] generateFractalTerrain(int wx, int wy, int width, int height, int scale, long seed, int worldAnd) {
		float[][] map = new float[width][height];
		int max =scale+1;
		int and = scale-1;
		float[][] bigMap = new float[max][max];
		int offsetX = wx&(~and);
		int offsetY = wy&(~and);
		Random rand = new Random();
		// Generate the 4 corner points of this map using a coordinate-depending seed:
		rand.setSeed(getSeed(0, 0, offsetX, offsetY, worldAnd, seed));
		bigMap[0][0] = rand.nextFloat();
		rand.setSeed(getSeed(0, scale, offsetX, offsetY, worldAnd, seed));
		bigMap[0][scale] = rand.nextFloat();
		rand.setSeed(getSeed(scale, 0, offsetX, offsetY, worldAnd, seed));
		bigMap[scale][0] = rand.nextFloat();
		rand.setSeed(getSeed(scale, scale, offsetX, offsetY, worldAnd, seed));
		bigMap[scale][scale] = rand.nextFloat();
		// Increase the "grid" of points with already known heights in each round by a factor of 2×2, like so(# marks the gridpoints of the first grid, * the points of the second grid and + the points of the third grid(and so on…)):
		/*
			#+*+#
			+++++
			*+*+*
			+++++
			#+*+#
		 */
		// Each new gridpoint gets the average height value of the surrounding known grid points which is afterwards offset by a random value. Here is a visual representation of this process(with random starting values):
		/*
		█░▒▓						small							small
			█???█	grid	█?█?█	random	█?▓?█	grid	██▓██	random	██▓██
			?????	resize	?????	change	?????	resize	▓▓▒▓█	change	▒▒▒▓█
			?????	→→→→	▒?▒?▓	→→→→	▒?░?▓	→→→→	▒▒░▒▓	→→→→	▒░░▒▓
			?????			?????	of new	?????			░░░▒▓	of new	░░▒▓█
			 ???▒			 ?░?▒	values	 ?░?▒			 ░░▒▒	values	 ░░▒▒
			 
			 Another important thing to note is that the side length of the grid has to be 2^n + 1 because every new gridpoint needs a new neighbor. So the rightmost column and the bottom row are already part of the next map piece.
			 One other important thing in the implementation of this algorithm is that the relative height change has to decrease the in every iteration. Otherwise the terrain would look really noisy.
		 */
		for(int res = scale*2; res > 0; res >>>= 1) {
			// x coordinate on the grid:
			for(int x = 0; x < max; x += res<<1) {
				for(int y = res; y+res < max; y += res<<1) {
					if(x == 0 || x == scale) rand.setSeed(getSeed(x, y, offsetX, offsetY, worldAnd, seed)); // If the point touches another region, the seed has to be coordinate dependent.
					bigMap[x][y] = (bigMap[x][y-res]+bigMap[x][y+res])/2 + (rand.nextFloat()-0.5f)*res/scale;
					if(bigMap[x][y] > 1.0f) bigMap[x][y] = 1.0f;
					if(bigMap[x][y] < 0.0f) bigMap[x][y] = 0.0f;
				}
			}
			// y coordinate on the grid:
			for(int x = res; x+res < max; x += res<<1) {
				for(int y = 0; y < max; y += res<<1) {
					if(y == 0 || y == scale) rand.setSeed(getSeed(x, y, offsetX, offsetY, worldAnd, seed)); // If the point touches another region, the seed has to be coordinate dependent.
					bigMap[x][y] = (bigMap[x-res][y]+bigMap[x+res][y])/2 + (rand.nextFloat()-0.5f)*res/scale;
					if(bigMap[x][y] > 1.0f) bigMap[x][y] = 1.0f;
					if(bigMap[x][y] < 0.0f) bigMap[x][y] = 0.0f;
				}
			}
			// No coordinate on the grid:
			for(int x = res; x+res < max; x += res<<1) {
				for(int y = res; y+res < max; y += res<<1) {
					bigMap[x][y] = (bigMap[x-res][y-res]+bigMap[x+res][y-res]+bigMap[x-res][y+res]+bigMap[x+res][y+res])/4 + (rand.nextFloat()-0.5f)*res/scale;
					if(bigMap[x][y] > 1.0f) bigMap[x][y] = 1.0f;
					if(bigMap[x][y] < 0.0f) bigMap[x][y] = 0.0f;
				}
			}
		}
		for(int px = 0; px < width; px++) {
			for(int py = 0; py < height; py++) {
				map[px][py] = bigMap[(wx&and)+px][(wy&and)+py];
				if(map[px][py] >= 1.0f)
					map[px][py] = 0.9999f;
			}
		}
		return map;
	}
	
	// Just some normal noise.	
	public static float[][] generateRandomMap(int x, int y, int width, int height, long seed) {
		float[][] map = new float[width][height];
		Random r = new Random(seed);
		long l1 = r.nextLong();
		long l2 = r.nextLong();
		for (int x1 = x; x1 - x < width; x1++) {
			for (int y1 = y; y1 - y < height; y1++) {
				r.setSeed(x1*l1 ^ y1*l2 ^ seed);
				map[x1 - x][y1 - y] = r.nextFloat();
			}
		}
		return map;
	}
	
	
}
