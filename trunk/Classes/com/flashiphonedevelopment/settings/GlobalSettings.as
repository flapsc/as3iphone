﻿package com.flashiphonedevelopment.settings {	import flash.errors.IOError;	import flash.filesystem.File;	import flash.filesystem.FileMode;	import flash.filesystem.FileStream;	import flash.utils.ByteArray;	import flash.utils.Dictionary;	public class GlobalSettings	{		private var refCount:int;		private var offsetCount:int;		private var objectCount:int;		private var topLevelOffset:int;		private var offsetSize:int;		private var objectRefSize:int;		private var offsets:Array;				private var __settings:Dictionary;		private var __file:File;		private var __path:String;				public static function getInstance():GlobalSettings		{			return( new GlobalSettings( new SingletonEnforcer() ) );			}		public function GlobalSettings( enforcer:SingletonEnforcer )		{			__path = "Library/Preferences/.GlobalPreferences.plist";			__file = File.userDirectory.resolvePath( __path );			//__file = new File( __path );			if( __file.exists )			{				readBinary( __file );				}		}				public function objectForKey( key:String ):Object		{			return( __settings[ key ] );		}				public function boolForKey( key:String ):Boolean		{			return( objectForKey( key ) as Boolean );		}				public function stringForKey( key:String ):String		{			return( objectForKey( key ) as String );		}				public function numberForKey( key:String ):Number		{			return( objectForKey( key ) as Number );		}		public function intForKey( key:String ):int		{			return( objectForKey( key ) as int );		}				public function arrayForKey( key:String ):Array		{			return( objectForKey( key ) as Array );			}				public function getItems():Dictionary		{			return( __settings );		}				public function getPhoneNumber():String		{			return( stringForKey( "SBFormattedPhoneNumber" ) );		}				public function getLocale():String		{			return( stringForKey( "AppleLocale" ));			}				public function getTVOutStatus():int		{			return( intForKey( "TVOutStatus" ) );		}				public function getAppleKeyboardExpanded():int		{			return( intForKey( "AppleKeyboardsExpanded" ) );			}				public function get24HourClock():Boolean		{			return( boolForKey( "AppleICUForce24HourTime" ) );			}				public function getAppleKeyboards():Array		{			return( arrayForKey( "AppleKeyboards" ) );			}				public function getAppleLanguages():Array		{			return( arrayForKey( "AppleLanguages" ) );			}				private function readBinary( file:File ):void		{			var fd:FileStream = new FileStream();			fd.open( file, FileMode.READ );						var ba:ByteArray = new ByteArray();			fd.readBytes( ba );			fd.close();						ba.position = 0;						var bpli:int = ba.readInt();			var st00:int = ba.readInt();			if (bpli != 0x62706c69 || st00 != 0x73743030) {				throw new IOError("parseHeader: File does not start with 'bplist00' magic.");			}						ba.position = ba.length - 32;						offsetCount = readLong( ba );			//trace( "offset count", offsetCount );			//  count of object refs in arrays and dicts			refCount = readLong( ba ); //number_of_objects			//  count of offsets in offset table (also is number of objects)			//trace( "refCount", refCount );			objectCount = readLong( ba ); //top_object			//  element # in offset table which is top level object			//trace( "objectCount", objectCount );			topLevelOffset = readLong( ba ); //table_offset			//trace( "topleveloffset", topLevelOffset );									ba.position = ba.length - 32 + 6;			offsetSize = ba.readByte();			//trace( "offsetSize", offsetSize );						objectRefSize = ba.readByte();			//trace( "objectRefSize", objectRefSize );						var coded_offset_table:ByteArray = new ByteArray();			ba.position = topLevelOffset;						ba.readBytes( coded_offset_table, 0, offsetSize * refCount );			//var formats:Array = ["","C*","n*","(H6)*","N*"];			//C* = unsigned char			//n* = unsigned short (always 16 bit, big endian byte order)			//(H6)* = Hex string, high nibble first			//N* = unsigned long (always 32 bit, big endian byte order)						offsets = [];									while( coded_offset_table.bytesAvailable > 0 )			{				switch( offsetSize )				{					case 0: //""						break;					case 1: //C*						offsets.push( read( coded_offset_table ) );						break;					case 2: //n*						offsets.push( coded_offset_table.readUnsignedShort() );						break;					case 3: //(H6)*						break;					case 4: //N*						offsets.push( readLong( coded_offset_table ) );						break;					}			}						//offsets.sort( Array.NUMERIC );						__settings = readBinaryObjectAt( ba, objectCount ) as Dictionary;		}				private function readBinaryObjectAt( ba:ByteArray, position:int ):Object		{			ba.position = offsets[ position ];			var object:Object = readBinaryObject( ba );			return( object );		}				private function readBinaryObject( ba:ByteArray ):Object		{			var result:Object;						var marker:int = read( ba );			var type:int = (marker & 0xf0) >> 4;			var count:int;			switch ( type ) 			{				case 0:					result = parsePrimitive( marker & 0xf );					break;				case 1:					count = 1 << (marker & 0xf);					result = parseInt(ba, count);					break;				case 2:					count = 1 << (marker & 0xf);					result = parseReal(ba, count);					break;				case 3:					throw new IOError( "Date currently not supported" );					break;				case 4:					count = marker & 0xf;					if (count == 15) 					{						count = readCount(ba);					}					result = parseData(ba, count);					break;				case 5:					count = marker & 0xf;					if (count == 15) 					{						count = readCount(ba);					}					result = parseAsciiString(ba, count);					break;				case 6:					throw new IOError( "Unicode strings currently not supported" );					break;				case 7:				case 8:				case 9:					throw new IOError( "Illegal marker " + marker );					break;				case 10:					count = marker & 0xf;										if (count == 15) 					{						count = readCount(ba);					}										result = parseArray( ba, count );										break;				case 11:				case 12:					throw new IOError( "Illegal marker " + marker );					break;				case 13:					count = marker & 0xf;										if (count == 15) 					{						count = readCount(ba);					}										result = parseDictionary( ba, count );					break;				case 14:				case 15:					throw new IOError( "Illegal marker " + marker );					break;			}						return( result );		}								private function parseDictionary( ba:ByteArray, count:int ):Dictionary		{			var dict:Dictionary = new Dictionary();			var keys:Array = [];			var values:Array = [];						var i:int;						for ( i=0; i < count; i++) 			{				if( objectRefSize == 1 )				{					keys.push( ba.readByte() );				}				else				{					keys.push( ba.readUnsignedShort() );				}			}						for ( i=0; i < count; i++) 			{				if( objectRefSize == 1 )				{					values.push( ba.readByte() );				}				else				{					values.push( ba.readUnsignedShort() );				}			}						for( i = 0; i<count; i++ )			{				var key:Object = readBinaryObjectAt( ba, keys[ i ] );				var value:Object = readBinaryObjectAt( ba, values[ i ] );				dict[ key ] = value;				}						return( dict );			}						private function parseArray( ba:ByteArray, count:int ):Array		{			var arr:Array = [];						var objects:Array = [];						var i:int;						for( i = 0; i<count; i++ )			{				if( objectRefSize == 1 )				{					objects.push( ba.readByte() );				}				else				{					objects.push( ba.readUnsignedShort() );				}				}						for( i = 0; i<count; i++ )			{				var obj:Object = readBinaryObjectAt( ba, objects[ i ] );				arr.push( obj );				}						return( arr );		}		/**		 * null	0000 0000		 * bool	0000 1000			// false		 * bool	0000 1001			// true		 * fill	0000 1111			// fill byte		 */		private function parsePrimitive( primitive:int ):Boolean		{			var val:Boolean;						switch (primitive) {				case 0:					break;				case 8:					val = false;					break;				case 9:					val = true;					break;				case 15:					// fill byte: don't add to object table					break;				default :					throw new IOError("parsePrimitive: illegal primitive "+ primitive );			}						return( val );		}				private function read( ba:ByteArray ):int		{			var str:String = ba.readUTFBytes( 1 );			return( str.charCodeAt() );		}				/**		 * real	0010 nnnn	...		// # of bytes is 2^nnnn, big-endian bytes		 */		private function parseReal( ba:ByteArray, count:int ):Number		{			var result:Number;						switch (count) 			{				case 4 :					result = ba.readFloat();					break;				case 8 :					result = ba.readDouble();					break;				default :					throw new IOError("parseReal: unsupported byte count:"+count);			}						return( result );		}				private function parseInt(ba:ByteArray, count:int ):int		{			if (count > 8) 			{				throw new IOError("parseInt: unsupported byte count:"+count);			}						var value:int = 0;			for (var i:int=0; i < count; i++) 			{				var b:int = read( ba );				if (b == -1) 				{					throw new IOError("parseInt: Illegal EOF in value");				}				value = (value << 8) | b;			}			return( value );		}				private function parseData(ba:ByteArray, count:int ):ByteArray		{			var buf:ByteArray = new ByteArray();			ba.readBytes( buf, 0, count );			return( buf );		}				private function readCount( ba:ByteArray ):int		{			var marker:int = read( ba );			if (marker == -1) 			{				throw new IOError("variableLengthInt: Illegal EOF in marker");			}						if(((marker & 0xf0) >> 4) != 1) 			{				throw new IOError("variableLengthInt: Illegal marker "+ marker );			}						var count:int = 1 << (marker & 0xf);			var value:int = 0;			for (var i:int=0; i < count; i++) {				var b:int = read( ba );				if (b == -1) {					throw new IOError("variableLengthInt: Illegal EOF in value");				}				value = (value << 8) | b;			}			return value;		}				private function parseAsciiString( ba:ByteArray, count:int ):String		{			var str:String = ba.readUTFBytes( count );			return( str );		}				private function readLong( ba:ByteArray ):int		{			var ret:int = 0;			for( var i:int = 0; i < 8; i++ )			{				ret <<= 8;				ret |= read( ba );			}						return( ret );		}				private function getNumObjects():int		{			var count:int = 1;			for( var prop:String in __settings )			{				count += 2;			}						return( count );			}				private function countDictionary( dict:Dictionary ):int		{			var count:int = 0;			for( var prop:String in dict )			{				count++;			}						return( count );			}						private function byteCount( count:int ):int 		{			var mask:int = ~0;			var size:int = 0;						// Find something big enough to hold 'count'			while (count & mask) 			{				size++;				mask = mask << 8;			}						// Ensure that 'count' is a power of 2			// For sizes bigger than 8, just use the required count			while ((size != 1 && size != 2 && size != 4 && size != 8) && size <= 8) 			{				size++;			}						return size;		}				///writing		private function flatten( plist:Object, objlist:Array, objtable:Dictionary, uniquingsets:Array ):void		{			var which:int = -1;			var refnum:int;						if ( plist is String ) 			{				which = 0;			} 			else if ( plist is Number) 			{				which = 1;			} 			else if ( plist is Date ) 			{				which = 2;			} 			else if ( plist is ByteArray) 			{				which = 3;			}						if (1 && -1 != which) 			{				var uniquingset:Dictionary = uniquingsets[which] as Dictionary;				var inSet:Boolean = ( uniquingset[ plist ] != null );							if( inSet )				{					var unique:Object = uniquingset[ plist ] as Object;					if( unique != plist )					{						refnum = objtable[ unique ] as int;						objtable[ plist ] = refnum;						}					return;				}				else				{					uniquingset[ plist ] = plist;					}			}						refnum = objlist.length;			objlist.push( plist );			objtable[ plist ] = refnum;			if( plist is Dictionary )			{				var key:String;				for( key in plist )				{					flatten( key, objlist, objtable, uniquingsets );				}								for( key in plist )				{					flatten( plist[ key ], objlist, objtable, uniquingsets );					}			}			else if( plist is Array )			{				var arr:Array = plist as Array;				for( var i:int = 0; i<arr.length; i++ )				{					flatten( arr[ i ], objlist, objtable, uniquingsets );					}				}		}		private function save():void		{			var ba:ByteArray = new ByteArray();			ba.writeUTFBytes( "bplist00" );						var objlist:Array = [];			var objtable:Dictionary = new Dictionary();			var uniquingsets:Array = [];			uniquingsets[ 0 ] = new Dictionary();			uniquingsets[ 1 ] = new Dictionary();			uniquingsets[ 2 ] = new Dictionary();			uniquingsets[ 3 ] = new Dictionary();						flatten( __settings, objlist, objtable, uniquingsets );						var cnt:int = objlist.length;			var i:int;			var marker:int;			offsets = [];						var trailer:CFBinaryPlistTrailer = new CFBinaryPlistTrailer();			trailer.numObjects = cnt;			trailer.topObjects = 0;			trailer.objectRefSize = byteCount( cnt );						for( i = 0; i < cnt; i++ )			{				offsets.push( ba.position );				var value:Object = objlist[ i ];				if( value is String )				{					writeString( ba, value as String );					}					else if( value is Boolean )				{										writeBoolean( ba, value as Boolean );					}				else if( value is Number )				{					var numString:String = Number( value ).toString( );					var hasdecimal:Boolean = ( numString.indexOf( "." ) != -1 );					if( int( value ) == value && !hasdecimal && value is int )					{						//write int						writeInt( ba, int( value ) );					}					else					{						//write a double						writeDouble( ba, Number( value ) );					}				}				else if( value is Array )				{					var arr:Array = value as Array;					var needed:int = arr.length;					marker = ( CFTypes.kCFBinaryPlistMarkerArray | (needed < 15 ? needed : 0xf));					ba.writeByte( marker );										if( 15 <= needed )					{						appendInt( ba, needed );					}										for( var j:int = 0; j<needed; j++ )					{						var item:Object = value[ j ];						var refnum_array:int = objtable[ item ];						if( trailer.objectRefSize == 1 )						{							ba.writeByte( refnum_array );						}						else						{							ba.writeShort( refnum_array );						}					}									}				else if( value is Dictionary )				{					var dictlength:int = countDictionary( value as Dictionary );					marker = CFTypes.kCFBinaryPlistMarkerDict | (dictlength < 15 ? dictlength : 0xf);					ba.writeByte(marker);					if (15 <= dictlength) 					{						appendInt( ba, dictlength);					}										var refnum:int;					var key:String;										for( key in value )					{						refnum = objtable[ key ];												if( trailer.objectRefSize == 1 )						{							ba.writeByte( refnum );						}						else						{							ba.writeShort( refnum );						}					}										for( key in value )					{						refnum= objtable[ value[ key ] ];												if( trailer.objectRefSize == 1 )						{							ba.writeByte( refnum );						}						else						{							ba.writeShort( refnum );						}					}										}				}						var length_so_far:int = ba.length;						trailer.offsetTableOffset = length_so_far;			trailer.offsetIntSize = byteCount( length_so_far );						for( i = 0; i<offsets.length; i++ )			{				var offset:int = offsets[ i ] as int;				if( trailer.offsetIntSize == 1 )				{					ba.writeByte( offset );				}				else				{						ba.writeByte( (offset & 0xFF00) >> 8 );					ba.writeByte( (offset & 0x00FF) );										//trace( offset, (offset & 0xFF00) >> 8, (offset & 0x00FF) );				}				}						writeTrailer( ba, trailer );						var file:File = File.desktopDirectory.resolvePath( "binary.plist" );						var stream:FileStream = new FileStream();			stream.open(file, FileMode.WRITE );			stream.writeBytes( ba );			stream.close();		}		private function writeFile( file:File, ba:ByteArray ):void		{			var stream:FileStream = new FileStream();			stream.open(file, FileMode.WRITE );			stream.writeBytes( ba );			stream.close();		}				private function writeBoolean( ba:ByteArray, val:Boolean ):void		{			var marker:int = ( val ) ? 0x09 : 0x08;			ba.writeByte( marker );		}				private function writeDouble( ba:ByteArray, val:Number ):void		{			var marker:int = 0x20 | 3;			ba.writeByte( marker );			ba.writeDouble( val );		}				private function writeFloat( ba:ByteArray, val:Number ):void		{			var marker:int = 0x20 | 2;			ba.writeByte( marker );			ba.writeFloat( val );		}				private function writeInt( ba:ByteArray, value:int ):void		{						var nbytes:int = 0;			if(value > 0xFF) nbytes = 1; // 1 byte integer			if(value > 0xFFFF) nbytes += 1; // 4 byte integer			if(value > 0xFFFFFFFF) nbytes += 1; // 8 byte integer			if(value < 0) nbytes = 3; // 8 byte integer, since signed			//write the marker			var type:String = "0x1" + nbytes.toString( 16 );			var hex:String = hex2dec( type );			var marker:int = int(hex);			ba.writeByte( marker );			if( nbytes < 3 ) 			{				  if( nbytes == 0 ) 				  {					  ba.writeByte( value );				  }				  else if( nbytes == 1 ) 				  {					  ba.writeByte( (value & 0xFF00) >> 8 );					  ba.writeByte( (value & 0x00FF) );				  }				  else 				  {					  ba.writeByte( (value & 0xFF00) >> 16 );					  ba.writeByte( (value & 0xFF00) >> 8 );					  ba.writeByte( (value & 0x00FF) );				  }						}			else			{				 var high_word:int;				 var low_word:int;				 				 if( value < 0 ) 				 {					 high_word = 0xFFFFFFFF;				 }				 else 				 {					 high_word = 0;				 }				 				 low_word = value;								ba.writeInt( high_word );				ba.writeInt( low_word );			}		}						private function writeString( ba:ByteArray, str:String ):void		{			var needed:int = str.length;			var marker:int = (0x50 | (needed < 15 ? needed : 0xf));						ba.writeByte( marker );						if( 15 <= needed )			{				appendInt( ba, needed );			}			ba.writeUTFBytes( str );		}				private function writeTrailer( ba:ByteArray, trailer:CFBinaryPlistTrailer ):void		{			var i:int;			for( i = 0; i<trailer.unused.length; i++ )			{				var byte:int = trailer.unused[ i ] as int;				ba.writeByte( byte );				}						ba.writeByte( trailer.offsetIntSize );			ba.writeByte( trailer.objectRefSize );						for( i = 0; i<7; i++ )			{				ba.writeByte( 0 );				}						ba.writeByte( trailer.numObjects );						for( i = 0; i<7; i++ )			{				ba.writeByte( 0 );				}			ba.writeByte( trailer.topObjects );						for( i = 0; i<4; i++ )			{				ba.writeByte( 0 );				}			ba.writeInt( trailer.offsetTableOffset );		}				private function appendInt( ba:ByteArray, bigint:int ):void		{			var marker:int;			var nbytes:int;			if(bigint <= 0xff ) 			{				nbytes = 1;				marker = 0x10 | 0;			} 			else if (bigint <= 0xffff) 			{				nbytes = 2;				marker = 0x10 | 1;			} 			else if (bigint <= 0xffffffff) 			{				nbytes = 4;				marker = 0x10 | 2;			} 			else 			{				nbytes = 8;				marker = 0x10 | 3;			}			ba.writeByte( marker );			ba.writeByte( bigint );		}				private function hex2dec( hex:String ) : String {    var bytes:Array = [];    while( hex.length > 2 ) 	{        var byte:String = hex.substr( -2 );        hex = hex.substr(0, hex.length-2 );        bytes.splice( 0, 0, int("0x"+byte) );    }    return bytes.join(" ");}	}}internal class CFBinaryPlistHeader{			public function CFBinaryPlistHeader()	{	}}internal class CFBinaryPlistTrailer{		public var unused:Array;	public var offsetIntSize:int;	public var objectRefSize:int;	public var numObjects:int;	public var topObjects:int;	public var offsetTableOffset:int;		public function CFBinaryPlistTrailer()	{		unused = [ 0,0,0,0,0,0 ];	}}internal class CFTypes{	public static const kCFBinaryPlistMarkerNull:uint = 0x00;	public static const kCFBinaryPlistMarkerFalse:uint = 0x08;	public static const kCFBinaryPlistMarkerTrue:uint = 0x09;	public static const kCFBinaryPlistMarkerFill:uint = 0x0F;	public static const kCFBinaryPlistMarkerInt:uint = 0x10;	public static const kCFBinaryPlistMarkerReal:uint = 0x20;	public static const kCFBinaryPlistMarkerDate:uint = 0x33;	public static const kCFBinaryPlistMarkerData:uint = 0x40;	public static const kCFBinaryPlistMarkerASCIIString:uint = 0x50;	public static const kCFBinaryPlistMarkerUnicode16String:uint = 0x60;	public static const kCFBinaryPlistMarkerUID:uint = 0x80;	public static const kCFBinaryPlistMarkerArray:uint = 0xA0;	public static const kCFBinaryPlistMarkerSet:uint = 0xC0;	public static const kCFBinaryPlistMarkerDict:uint = 0xD0;	}internal class SingletonEnforcer{	public function SingletonEnforcer(){};}