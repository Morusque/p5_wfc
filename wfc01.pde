
import java.util.HashSet;
import java.util.Queue;
import java.util.LinkedList;
import java.util.Map;

PImage pattern;
int[][] inputGrid;  // Grid for the input pattern
int[][] outputGrid; // Grid for the output pattern <- for optimization this should probably also contain the possibilities and only be updated when needed, not recomputed every time 
ArrayList<Tile> tiles = new ArrayList<Tile>();
int tileWidth = 4;
int tileHeight = 4;

void setup() {
  size(512, 512);
  pattern = loadImage("pattern.png");
  pattern.loadPixels(); // Load the pixels of the pattern
  analyzePattern();
  initializeOutputGrid();
  frameRate(100);
}

class Tile {
  PImage im;
  int frequency;
  int index;
  ArrayList<Integer>[] adjacencies;
  ArrayList<Integer>[] frequencies;
  Tile (PImage im) {
    this.im=im;
  }
  boolean imageEquals(PImage im2) {
    if (im2.width!=im.width||im2.height!=im.height) return false;
    for (int x=0; x<im2.width; x++) {
      for (int y=0; y<im2.height; y++) {
        color c1 = im.get(x, y);
        color c2 = im2.get(x, y);
        if (red(c1) != red(c2)) return false;
        if (green(c1) != green(c2)) return false;
        if (blue(c1) != blue(c2)) return false;
      }
    }
    return true;
  }
}

void analyzePattern() {
  int inputGridWidth = ceil((float) pattern.width);
  int inputGridHeight = ceil((float) pattern.height);
  inputGrid = new int[inputGridWidth][inputGridHeight];

  PGraphics doubledPattern = createGraphics(pattern.width + tileWidth, pattern.height + tileHeight);
  doubledPattern.beginDraw();
  doubledPattern.image(pattern, 0, 0);
  doubledPattern.image(pattern, 0, pattern.height);
  doubledPattern.image(pattern, pattern.width, 0);
  doubledPattern.image(pattern, pattern.width, pattern.height);
  doubledPattern.endDraw();

  for (int x = 0; x < pattern.width; x++) {
    for (int y = 0; y < pattern.height; y++) {
      PImage thisTile = doubledPattern.get(x, y, tileWidth, tileHeight);
      boolean found = false;
      for (int i = 0; i < tiles.size(); i++) {
        if (tiles.get(i).imageEquals(thisTile)) {
          inputGrid[x][y] = i;
          found = true;
          break;
        }
      }
      if (!found) {
        Tile newTile = new Tile(thisTile);
        newTile.index = tiles.size();
        newTile.frequency = 1;
        tiles.add(newTile);
        inputGrid[x][y] = newTile.index;
      } else {
        tiles.get(inputGrid[x][y]).frequency++;
      }
    }
  }

  // Initialize adjacency and frequency lists for each tile
  for (Tile tile : tiles) {
    tile.adjacencies = new ArrayList[4];
    tile.frequencies = new ArrayList[4];
    for (int i = 0; i < 4; i++) {
      tile.adjacencies[i] = new ArrayList<>();
      tile.frequencies[i] = new ArrayList<>();
    }
  }

  // Analyze adjacency and frequency for each direction
  for (int x = 0; x < inputGridWidth; x++) {
    for (int y = 0; y < inputGridHeight; y++) {
      int tileIndex = inputGrid[x][y];
      updateAdjacencyWithFrequency(x, y - tileHeight, tileIndex, 0); // Up
      updateAdjacencyWithFrequency(x + tileWidth, y, tileIndex, 1); // Right
      updateAdjacencyWithFrequency(x, y + tileHeight, tileIndex, 2); // Down
      updateAdjacencyWithFrequency(x - tileWidth, y, tileIndex, 3); // Left
    }
  }

  // Remove duplicates from adjacency lists
  for (Tile tile : tiles) {
    for (int i = 0; i < 4; i++) {
      HashSet<Integer> unique = new HashSet<>(tile.adjacencies[i]);
      tile.adjacencies[i].clear();
      tile.adjacencies[i].addAll(unique);

      // Adjust frequency list size to match adjacency list
      while (tile.frequencies[i].size() < tile.adjacencies[i].size()) {
        tile.frequencies[i].add(0);
      }
    }
  }

  printAdjacencyRules();
}

void updateAdjacencyWithFrequency(int x, int y, int tileIndex, int direction) {
  if (x >= 0 && x < inputGrid.length && y >= 0 && y < inputGrid[0].length) {
    int neighborIndex = inputGrid[x][y];
    if (neighborIndex != -1) {
      ArrayList<Integer> adjacencyList = tiles.get(tileIndex).adjacencies[direction];
      ArrayList<Integer> frequencyList = tiles.get(tileIndex).frequencies[direction];
      int indexInAdjacency = adjacencyList.indexOf(neighborIndex);
      if (indexInAdjacency == -1) {
        adjacencyList.add(neighborIndex);
        frequencyList.add(1);
      } else {
        frequencyList.set(indexInAdjacency, frequencyList.get(indexInAdjacency) + 1);
      }
    }
  }
}

void printAdjacencyRules() {
  for (Tile t : tiles) {
    println("Tile Index: " + t.index);
    println("  Frequency: " + t.frequency);
    println("  Up:        " + t.adjacencies[0]+ " / "+t.frequencies[0]);
    println("  Right:     " + t.adjacencies[1]+ " / "+t.frequencies[1]);
    println("  Down:      " + t.adjacencies[2]+ " / "+t.frequencies[2]);
    println("  Left:      " + t.adjacencies[3]+ " / "+t.frequencies[3]);
    println();
    // tiles.get(tileIndex).im.save("tiles/"+nf(tileIndex, 5)+".png");
  }
}

void initializeOutputGrid() {
  // Initialize the output grid
  outputGrid = new int[ceil(width/tileWidth)][ceil(height/tileHeight)];
  for (int x = 0; x < outputGrid.length; x++) {
    for (int y = 0; y < outputGrid[x].length; y++) {
      outputGrid[x][y] = -1; // -1 to represent an undecided state
    }
  }
}

int[] findCellWithLeastEntropy() {
  float minEntropy = Float.MAX_VALUE;
  ArrayList<int[]> possibilities = new ArrayList<int[]>();
  for (int x = 0; x < outputGrid.length; x++) {
    for (int y = 0; y < outputGrid[x].length; y++) {
      if (outputGrid[x][y] == -1) { // Only consider undecided cells
        ArrayList<PossibleTileWeighted> possibleTiles = getPossibleTiles(x, y);
        float entropy = 0;
        for (PossibleTileWeighted p : possibleTiles) entropy += 1.0; // entropy += 1.0/(p.frequency+1)
        if (entropy < minEntropy) {
          minEntropy = entropy;
          possibilities.clear();
          possibilities.add(new int[]{x, y});
        } else if (entropy == minEntropy) {
          minEntropy = entropy;
          possibilities.add(new int[]{x, y});
        }
      }
    }
  }
  if (possibilities.size()==0) return new int[]{-1, -1};
  return possibilities.get(floor(random(possibilities.size())));
}

boolean complete=false;
void collapseWaveFunction() {
  if (complete) return;
  int[] cellIndex = findCellWithLeastEntropy();
  if (cellIndex[0] == -1) {
    save("lastResult.png");
    complete=true;
    return; // No more cells to collapse, generation is complete
  }
  int x = cellIndex[0];
  int y = cellIndex[1];
  int selectedTile = selectTileBasedOnConstraints(x, y);
  if (selectedTile!=-1) {
    outputGrid[x][y] = selectedTile;
  } else outputGrid[x][y] = -2; // Deliberate empty tile
  propagateConstraints(x, y);
}

ArrayList<PossibleTileWeighted> getPossibleTiles(int x, int y) {
  HashSet<Integer> possibleTiles = new HashSet<>();
  for (int i = 0; i < tiles.size(); i++) possibleTiles.add(i);// Initially, consider all tiles as possible

  // Refine the possible tiles based on neighboring cells
  if (x > 0 && outputGrid[x - 1][y] != -1 && outputGrid[x - 1][y] != -2) possibleTiles.retainAll(tiles.get(outputGrid[x - 1][y]).adjacencies[1]); // Keep tiles that can be to the right of the left neighbor
  if (y > 0 && outputGrid[x][y - 1] != -1 && outputGrid[x][y - 1] != -2) possibleTiles.retainAll(tiles.get(outputGrid[x][y - 1]).adjacencies[2]); // Keep tiles that can be below the top neighbor
  if (x < outputGrid.length - 1 && outputGrid[x + 1][y] != -1 && outputGrid[x + 1][y] != -2) possibleTiles.retainAll(tiles.get(outputGrid[x + 1][y]).adjacencies[3]); // Keep tiles that can be to the left of the right neighbor
  if (y < outputGrid[0].length - 1 && outputGrid[x][y + 1] != -1 && outputGrid[x][y + 1] != -2) possibleTiles.retainAll(tiles.get(outputGrid[x][y + 1]).adjacencies[0]); // Keep tiles that can be above the bottom neighbor

  // Calculate frequencies for each possible tile
  Tile[] neighbors = neighbors(x, y);
  ArrayList<PossibleTileWeighted> possibleTilesWeighted = new ArrayList<>();
  int totalFrequency = 0;
  for (int i : possibleTiles) {
    int frequency = 0;
    for (int dir = 0; dir < 4; dir++) {
      if (neighbors[dir] != null) {
        int indexOfI = neighbors[dir].adjacencies[(dir + 2) % 4].indexOf(i); // Opposite direction for adjacency
        if (indexOfI != -1) {
          frequency += neighbors[dir].frequencies[(dir + 2) % 4].get(indexOfI);
          totalFrequency += neighbors[dir].frequencies[(dir + 2) % 4].get(indexOfI);
        }
      }
    }
    possibleTilesWeighted.add(new PossibleTileWeighted(i, frequency));
  }
  // if (totalFrequency==0) for(PossibleTileWeighted p : possibleTilesWeighted) p.frequency = 1;
  return possibleTilesWeighted;
}

Tile[] neighbors(int x, int y) {
  Tile[] neighbors = new Tile[4]; // 0: up, 1: right, 2: down, 3: left

  // Up
  if (y > 0 && outputGrid[x][y - 1] >= 0) {
    neighbors[0] = tiles.get(outputGrid[x][y - 1]);
  } else {
    neighbors[0] = null;
  }

  // Right
  if (x < outputGrid.length - 1 && outputGrid[x + 1][y] >= 0) {
    neighbors[1] = tiles.get(outputGrid[x + 1][y]);
  } else {
    neighbors[1] = null;
  }

  // Down
  if (y < outputGrid[0].length - 1 && outputGrid[x][y + 1] >= 0) {
    neighbors[2] = tiles.get(outputGrid[x][y + 1]);
  } else {
    neighbors[2] = null;
  }

  // Left
  if (x > 0 && outputGrid[x - 1][y] >= 0) {
    neighbors[3] = tiles.get(outputGrid[x - 1][y]);
  } else {
    neighbors[3] = null;
  }

  return neighbors;
}

class PossibleTileWeighted {
  int index;
  int frequency;
  PossibleTileWeighted(int index, int frequency) {
    this.index=index;
    this.frequency=frequency;
  }
}

ArrayList<Integer> PossibleTileIndexes(ArrayList<PossibleTileWeighted> possibleTilesWeighted) {
  ArrayList<Integer> possibleTileIndexes = new ArrayList<Integer>();
  for (PossibleTileWeighted p : possibleTilesWeighted) possibleTileIndexes.add(p.index);
  return possibleTileIndexes;
}

void propagateConstraints(int collapsedX, int collapsedY) {
  Queue<int[]> queue = new LinkedList<int[]>();
  queue.add(new int[]{collapsedX, collapsedY});

  while (!queue.isEmpty()) {
    int[] cell = queue.remove();
    int x = cell[0];
    int y = cell[1];

    // Check and update each neighboring cell
    updateNeighbor(x - 1, y, queue); // Left neighbor
    updateNeighbor(x + 1, y, queue); // Right neighbor
    updateNeighbor(x, y - 1, queue); // Top neighbor
    updateNeighbor(x, y + 1, queue); // Bottom neighbor
  }
}

void updateNeighbor(int x, int y, Queue<int[]> queue) {
  if (x >= 0 && x < outputGrid.length && y >= 0 && y < outputGrid[0].length && outputGrid[x][y] == -1) {
    ArrayList<Integer> possibleTilesBeforeUpdate = PossibleTileIndexes(getPossibleTiles(x, y));
    // Decide a new tile based on updated constraints
    int selectedTile = selectTileBasedOnConstraints(x, y);
    // If the new tile is different from the current tile
    if (selectedTile != -1 && !possibleTilesBeforeUpdate.contains(selectedTile)) {
      // Update the grid with the new tile selection
      outputGrid[x][y] = selectedTile;
      // Since the state of this cell has changed, add its neighbors to the queue
      queue.add(new int[]{x, y});
    }
  }
}

int selectTileBasedOnConstraintsOnlyGloballyWeighted(int x, int y) {
  ArrayList<Integer> possibleTiles = PossibleTileIndexes(getPossibleTiles(x, y));
  if (possibleTiles.isEmpty()) return -2; // Indicate a contradiction
  ArrayList<Integer> weightedPossibleTiles = new ArrayList<>();
  for (int tileIndex : possibleTiles) {
    int frequency = tiles.get(tileIndex).frequency;
    for (int i = 0; i < frequency; i++) weightedPossibleTiles.add(tileIndex);
  }
  if (weightedPossibleTiles.isEmpty()) return -2; // Fallback in case of an error or contradiction
  int selectedIndex = floor(random(weightedPossibleTiles.size()));
  return weightedPossibleTiles.get(selectedIndex);
}

int selectTileBasedOnConstraints(int x, int y) {
  ArrayList<PossibleTileWeighted> possibleTiles = getPossibleTiles(x, y);
  if (possibleTiles.isEmpty()) return -2; // Indicate a contradiction
  ArrayList<Integer> weightedPossibleTiles = new ArrayList<Integer>();
  for (PossibleTileWeighted tile : possibleTiles) {
    for (int i = 0; i < tile.frequency+1; i++) {
      weightedPossibleTiles.add(tile.index);
    }
  }
  if (weightedPossibleTiles.isEmpty()) return -2; // Fallback in case of an error or contradiction
  int selectedIndex = floor(random(weightedPossibleTiles.size()));
  return weightedPossibleTiles.get(selectedIndex);
}

boolean isGenerationComplete() {
  for (int x = 0; x < outputGrid.length; x++) {
    for (int y = 0; y < outputGrid[x].length; y++) {
      if (outputGrid[x][y] == -1) { // -1 indicates an undecided cell
        return false;
      }
    }
  }
  return true;
}

void draw() {
  collapseWaveFunction();
  background(255); // Set background to white (or any other color of your choice)
  for (int x = 0; x < outputGrid.length; x++) {
    for (int y = 0; y < outputGrid[x].length; y++) {
      drawTile(x, y);
    }
  }
}

void keyPressed() {
  if (keyCode==TAB) save("result.png");
}

void drawTile(int gridX, int gridY) {
  int tileIndex = outputGrid[gridX][gridY];

  if (tileIndex == -1) {
    // Optionally handle undecided cells
    /*
    fill(0, 0, 200); // Example: a light gray color for empty tiles
     noStroke();
     rect(gridX * tileWidth, gridY * tileHeight, tileWidth, tileHeight);
     */
  } else if (tileIndex == -2) {
    // Handle deliberate empty tiles, e.g., draw a specific color or pattern
    fill(200, 0, 0); // Example: a light gray color for empty tiles
    noStroke();
    rect(gridX * tileWidth, gridY * tileHeight, tileWidth, tileHeight);
  } else {
    // Draw the actual tile
    PImage tileImage = tiles.get(tileIndex).im; // Assuming each tile index corresponds to an image
    image(tileImage, gridX * tileWidth, gridY * tileHeight, tileWidth, tileHeight);
  }
}
