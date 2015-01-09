/* --------------------------------------------------------------------- */
/* --------------------- A 3D Conways Game of Life --------------------- */
/* ------------------------- for the L3D Cube -------------------------- */
/* ------------------------ Written by lapentab ------------------------ */
/* --------------------------------------------------------------------- */
/* | This code uses findings and notation from this paper:             | */
/* | http://www.complex-systems.com/pdf/01-3-1.pdf                     | */
/* | Rule values and cube dimensions can be easily set. The game will  | */
/* | reset upon reaching a stable endstate, where all cells have been  | */
/* | the same for a while, or all cells have died. Currently, this code| */
/* | is unable to detect oscillatory life, and must currently be reset | */
/* | manually if hitting an oscillary state.                           | */
/* --------------------------------------------------------------------- */

import L3D.*;

L3D cube;
// Dimensions of the cube
int cubeWidth = 16;
// Number of frames between a step.
int frameSteps = 10;
// Freeze delay. How long to display endstate before reset, in ms.
int freezeDelay = 1000;

/* -------------------------------------------------------------------- */
/* -------- Rule Values, using notation from above cited paper -------- */
/* -------------------------------------------------------------------- */
// Interesting values: 4,5,5,5 (gliders); 1,8,5,5 (large stable state); 5,7,6,6 (Lots of stable small objects)

int seedLiveProbability= 40; // Initial Seed Value, probability for a cell to be active. Between 20-40 is good

int El = 5; // Low bound of neighbors of a cell to continue living if alive
int Eh = 7; // High bound of neighbors of a cell to continue living if alive
int Fl = 6; // Low bound of neighbors of a cell to be born if not alive
int Fh = 6; // High bound of neighbors of a cell to be born if not alive

int state[][][] = new int[cubeWidth][cubeWidth][cubeWidth];

// Sets the array to a random starting state, then draws it on the cube. 
// Using the seedLiveProbability to determing probability a cell is initially alive.
void seed() {
  for (int i=0; i<cubeWidth; i++) {
    for (int j=0; j<cubeWidth; j++) {
      for (int k=0; k<cubeWidth; k++) {
        if (random(100) <= seedLiveProbability) state[i][j][k]=1;
        else state[i][j][k] = 0;
      }
    }
  }
  redrawFromArray();
}

// This function will update the voxels. Setting them to red if they are newly born, and transitioning 
// the colours from red->yellow->green for the number of steps they are alive. This is so you can
// see what cells have survived the longest. Also to detect a non-oscillating end state.
// returns 1 if the pixel is the most green state (used to determine end condition)
int setVoxelToNewValue(int i, int j, int k, int voxelAlive) {
  if (voxelAlive==1) {
    int currentVoxelValue = cube.getVoxel(i, j, k);
    if (currentVoxelValue !=unhex("FF000000")) { // If not lit
      if (currentVoxelValue != unhex("FF00FF00")) { // If it is not completely green
        if (((currentVoxelValue >>8) & 0xFF)  == unhex("FF")) { // If it already reached the highest green value, subtract red (to flip from yellow to green)
          cube.setVoxel(i, j, k, currentVoxelValue - color(51, 0, 0, 0)); // Decrease R value
          return 0;
        } else {
          cube.addVoxel(i, j, k, color(0, 51, 0)); // Increase G value
          return 0;
        }
      }
      return 1;
    } else {
      cube.setVoxel(i, j, k, color(255, 0, 0)); // It is newly alive! Set to red.
      return 0;
    }
  } else {
    cube.setVoxel(i, j, k, unhex("FF000000")); // It died. Set it to inactive!
    return 1;
  }
}

// This function redraws the cube from a 3D integer away representing the state.
// This function returns a boolean to detect if all of the living cells are green, or if no cells remain.
// This is used to detect a non-oscillating end state for resets.
boolean redrawFromArray() {
  boolean areAllGreen = true;
  for (int i=0; i<cubeWidth; i++) {
    for (int j=0; j<cubeWidth; j++) {
      for (int k=0; k<cubeWidth; k++) {
        int voxelValue = setVoxelToNewValue(i, j, k, state[i][j][k]);
        if (areAllGreen && voxelValue == 0) areAllGreen = false;
      }
    }
  }
  return areAllGreen;
}

void setup()
{
  size(displayWidth, displayHeight, P3D);
  cube=new L3D(this, cubeWidth);
  cube.enableDrawing(); 
  cube.enableMulticastStreaming();  
  cube.enablePoseCube();
  seed();
}

// Checks neighbors of a cell and returns whether it will live or not
// based on the rule values given. Takes in a single cell's PVector coordinates.
int doILive(PVector v) {
  int numNeighbors = 0;
  int x = (int) v.x;
  int y = (int) v.y;
  int z = (int) v.z;
  int isAlive = state[x][y][z];
  // Iterate through all of the neighbors.
  for (int i=-1; i<=1; i++) {
    for (int j=-1; j<=1; j++) {
      for (int k=-1; k<=1; k++) {
        if (!(i==0 && j==0 && k==0)) { // Do not want to count the test cell itself.
          try { // This is hacky and you should not do this but hnng it makes the code so much cleaner looking.
            if (state[x+i][y+j][z+k] == 1) numNeighbors++;
          } 
          catch (Exception e) {
          }
        }
      }
    }
  }
  if ((numNeighbors >= Fl && numNeighbors <= Fh) && isAlive == 0) { // Will it be born?
    return 1;
  }
  if ((numNeighbors < El || numNeighbors >Eh) && isAlive == 1) { // Should it die?
    return 0;
  }
  return isAlive; // If it hit neither of the cases above, it stays how it was.
}

// Updates the array one step, killing and birthing cells that should be killed and birthed.
// Returns the updated array.
int[][][] updateArray() {
  int[][][] toReturn = new int[cubeWidth][cubeWidth][cubeWidth];
  for (int i=0; i<cubeWidth; i++) {
    for (int j=0; j<cubeWidth; j++) {
      for (int k=0; k<cubeWidth; k++) {
        PVector currentCell = new PVector(i, j, k);
        toReturn[i][j][k] = doILive(currentCell);
      }
    }
  } 
  return toReturn;
}

boolean freezeForReset = false;

void draw()
{
  background(0);
  if (freezeForReset) {
    try { 
      Thread.sleep(freezeDelay); //Pause on the endstate for a bit.
    } 
    catch (Exception e) {
    }      
    cube.background(unhex("FF000000")); // reset the cube completely
    seed(); // reseed it to a random state
    freezeForReset = false; // Good to go back to normal!
  }
  if ((frameCount%frameSteps)==0 && !freezeForReset) { 
    state = updateArray(); // move forward a step.
    if (redrawFromArray()) { // If this is true, all of the cells are green or dead, and a reset is needed!
      freezeForReset = true;
    }
  }
}

