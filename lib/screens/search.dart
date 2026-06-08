import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:libera/common/utils.dart';
import 'package:libera/model/search_model.dart';
import 'package:libera/services/api_service.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  ApiServices apiServices = ApiServices();
  TextEditingController searchController = TextEditingController();
  Search? search;
  void searching(String query) {
    apiServices.fetchSearch(query).then((result) {
      setState(() {
        search = result;
      });
    });
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            CupertinoSearchTextField(
              controller: searchController,
              padding: EdgeInsetsGeometry.all(10),
              prefixIcon: Icon(CupertinoIcons.search, color: Colors.grey),
              suffixIcon: Icon(Icons.cancel, color: Colors.white),
              style: TextStyle(color: Colors.white),
              backgroundColor: Colors.grey.shade300,
              onChanged: (value) {
                if (value.isNotEmpty) {
                  searching(searchController.text);
                }
              },
            ),
            searchController.text.isEmpty
                ? SizedBox()
                : search == null
                ? SizedBox.shrink()
                : ListView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    itemCount: search?.results.length,
                    itemBuilder: (context, index) {
                      final searched = search!.results[index];
                      return searched.backdropPath == null
                          ? SizedBox()
                          : Stack(
                              children: [
                                Padding(
                                  padding: EdgeInsetsGeometry.all(5),
                                  child: InkWell(
                                    onTap: () {},
                                    child: Container(
                                      height: 90,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Row(
                                        children: [
                                          CachedNetworkImage(
                                            imageUrl:
                                                "$imageUrl${searched.backdropPath}",
                                            fit: BoxFit.contain,
                                            width: 150,
                                          ),
                                          SizedBox(width: 20),
                                          Flexible(
                                            child: Text(
                                              searched.name ??
                                                  searched.title ??
                                                  '',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  child: Icon(
                                    Icons.play_circle,
                                    color: Colors.white,
                                    size: 27,
                                  ),
                                ),
                              ],
                            );
                    },
                  ),
          ],
        ),
      ),
    );
  }
}
