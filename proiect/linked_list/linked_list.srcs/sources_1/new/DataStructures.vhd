

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

package DataStructures is
   type LinkedList is protected
  
      procedure Push(constant Data : in integer);
      impure function Pop return integer;
      impure function IsEmpty return boolean;
  
   end protected;
end package DataStructures;
  
package body DataStructures is
  
   type LinkedList is protected body
  
      type Item;
      type Ptr is access Item;
      type Item is record
         Data : integer;
         NextItem : Ptr;
      end record;
  
      variable Root : Ptr;
  
      procedure Push(Data : in integer) is
         variable NewItem : Ptr;
         variable Node : Ptr;
      begin
         NewItem := new Item;
         NewItem.Data := Data;
  
         if Root = null then
            Root := NewItem;
  
         else
            Node := Root;
  
            while Node.NextItem /= null loop
               Node := Node.NextItem;
            end loop;
  
            Node.NextItem := NewItem;
         end if;
      end;
  
      impure function Pop return integer is
         variable Node : Ptr;
         variable RetVal : integer;
      begin
         Node := Root;
         Root := Root.NextItem;
  
         RetVal := Node.Data;
         deallocate(Node);
  
         return RetVal;
      end;
  
      impure function IsEmpty return boolean is
      begin
         return Root = null;
      end;
  
   end protected body;
  
end package body DataStructures;
