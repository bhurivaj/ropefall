require "sketchup.rb"
Sketchup::require "sketchrope_ropefall/constants"

module SKETCHROPE_ROPEFALL

# Raised when a rope point leaves the indexed fall room; the animation stops and keeps the rope
class OutOfRoomError < StandardError; end

class Grid
    def initialize(cubeSize, roomBounds, skip = nil)
        @skip = skip
        @fallRoomBounds = extendBoundingBoxToBottom(cubeSize, roomBounds)
        @cubeSize = cubeSize * 1.5
        
        @binsOneDimX = (@fallRoomBounds.width / @cubeSize).floor + 1
        @binsOneDimY = (@fallRoomBounds.height / @cubeSize).floor + 1
        @binsOneDimZ = (@fallRoomBounds.depth / @cubeSize).floor + 1
        puts "binsOneDimX = " + @binsOneDimX.to_s
        puts "binsOneDimY = " + @binsOneDimY.to_s
        puts "binsOneDimZ = " + @binsOneDimZ.to_s
        
        fillIndex()                
        #drawGrid()
    end
    
    def extendBoundingBoxToBottom(cubeSize, roomBounds)
        res = Geom::BoundingBox.new
        bottom = SKETCHROPE_ROPEFALL::modelBottom(@skip)
                    
        res.add(Geom::Point3d.new(roomBounds.min.x - cubeSize, roomBounds.min.y - cubeSize, bottom - cubeSize))
        res.add(Geom::Point3d.new(roomBounds.max.x + cubeSize, roomBounds.max.y + cubeSize, roomBounds.max.z + cubeSize))
        
        return res
    end
    
    def drawGrid()
        SKETCHROPE_ROPEFALL::entities.add_cline [@fallRoomBounds.min.x, @fallRoomBounds.min.y, @fallRoomBounds.min.z], [@fallRoomBounds.max.x, @fallRoomBounds.min.y, @fallRoomBounds.min.z]
        SKETCHROPE_ROPEFALL::entities.add_cline [@fallRoomBounds.min.x, @fallRoomBounds.min.y, @fallRoomBounds.min.z], [@fallRoomBounds.min.x, @fallRoomBounds.max.y, @fallRoomBounds.min.z]
        SKETCHROPE_ROPEFALL::entities.add_cline [@fallRoomBounds.min.x, @fallRoomBounds.min.y, @fallRoomBounds.min.z], [@fallRoomBounds.min.x, @fallRoomBounds.min.y, @fallRoomBounds.max.z]
    end
    
    def fillIndex()
        @faces = SKETCHROPE_ROPEFALL::getAllFaces(@fallRoomBounds, @skip)
        
        @faces.each{|f|
            faceBounds = f.bounds
            minIndex = extendMin(toGridIndex(faceBounds.min))
            maxIndex = extendMax(toGridIndex(faceBounds.max))
            
            if (maxIndex[0] < 0 || maxIndex[1] < 0 || maxIndex[2] < 0 || minIndex[0] > @binsOneDimX || minIndex[1] > @binsOneDimY || minIndex[2] > @binsOneDimZ)
                next
            end
            
            for i in minIndex[0]..maxIndex[0]
                for j in minIndex[1]..maxIndex[1]
                    for k in minIndex[2]..maxIndex[2]
                        registerFace(f, i, j, k)
                    end
                end
            end
        }
    end

    def min(a, b)
        return a < b ? a : b
    end
    
    def max(a, b)
        return a > b ? a : b
    end
    
    def extendMin(minIndex)
       return [max(0, minIndex[0] - 1), max(0, minIndex[1] - 1), max(0, minIndex[2] - 1)] 
    end
    
    def extendMax(maxIndex)
       return [min(@binsOneDimX, maxIndex[0] + 1), min(@binsOneDimY, maxIndex[1] + 1), min(@binsOneDimZ, maxIndex[2] + 1)] 
    end

    def getFacesArray(i, j, k)
        if (@facesIndex == nil)
            @facesIndex = Array.new(@binsOneDimX, nil)
        end
        
        facesIndexY = @facesIndex[i]
        
        if (facesIndexY == nil)
            facesIndexY = Array.new(@binsOneDimY, nil)
            @facesIndex[i] = facesIndexY
        end
        
        facesIndexZ = facesIndexY[j]
        
        if (facesIndexZ == nil)
            facesIndexZ = Array.new(@binsOneDimZ, nil)
            facesIndexY[j] = facesIndexZ            
        end
        
        faces = facesIndexZ[k]
        
        if (faces == nil)
            faces = []
            facesIndexZ[k] = faces
        end
        
        return faces
    end
    
    def isWithinBounds(i, j, k)
        if (i < 0 || i >= @binsOneDimX || j < 0 || j >= @binsOneDimY || k < 0 || k >= @binsOneDimZ)
            return false
        end
        
        return true
    end
    
    def registerFace(f, i, j, k)
        if (!isWithinBounds(i, j, k))
            return false
        end        
            
        faces = getFacesArray(i, j, k)
        
        if (!faces.include?(f))
            faces << f
        end
    end

    def toGridIndex(p)
        shifted_p = p.offset(Geom::Point3d.new - @fallRoomBounds.min)
        
        return [(shifted_p.x / @cubeSize).floor, (shifted_p.y / @cubeSize).floor, (shifted_p.z / @cubeSize).floor]
    end
    
    def getFaces(a_p, b_p)
        a_index = toGridIndex(a_p)
        i = a_index[0]
        j = a_index[1]
        k = a_index[2]
        
        if (!isWithinBounds(i, j, k))
            raise OutOfRoomError, "rope left the simulation area"
        end        
        
        if (@facesIndex == nil || @facesIndex[i] == nil || @facesIndex[i][j] == nil || @facesIndex[i][j][k] == nil)
            return []
        end
        
        return @facesIndex[i][j][k]        
    end

end

end
